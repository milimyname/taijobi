#!/bin/bash
# Build and ship everything the Hetzner VPS serves for taijobi, straight from
# this Mac (same model as wimg's scripts/deploy-server.sh — no server SSH key
# in CI). CI keeps building iOS + the GitHub Release.
#
# Usage:
#   ./scripts/deploy-server.sh          # sync server + web app
#   ./scripts/deploy-server.sh sync     # sync server only (sync.taijobi.com)
#   ./scripts/deploy-server.sh web      # web app only (taijobi.com)
#   ./scripts/deploy-server.sh data     # dictionary .bin files → /var/www/taijobi/data
#
# VPS defaults to the `wimg-vps` alias in ~/.ssh/config (the shared box that
# also serves eigenheim, packsil and wimg). Override with VPS=root@<ip>.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

VPS="${VPS:-wimg-vps}"
WHAT="${1:-all}"
# Ubuntu 24.04 on x86_64 (glibc 2.39). Without an explicit target zig builds a
# Mac binary.
SYNC_TARGET="x86_64-linux-gnu.2.39"
SYNC_PORT=8092
# Where `data` fetches dictionaries it can't find locally. While taijobi.com is
# still on Cloudflare this is the R2-backed copy the apps download today.
DATA_SOURCE="${DATA_SOURCE:-https://taijobi.com/data}"
DICTS=(cedict decomp strokes endict dedict)

die() { echo "error: $1" >&2; exit 1; }

case "$WHAT" in
	all | web | sync | data) ;;
	*) die "unknown target '$WHAT' (use: all, sync, web, data)" ;;
esac

ssh -o ConnectTimeout=10 "$VPS" true || die "can't reach $VPS over SSH"
IP="$(ssh -G "$VPS" | awk '/^hostname /{print $2}')"

# Hit the box's public IP with the right SNI/Host, bypassing DNS: before the
# DNS switch the names still resolve to Cloudflare. -k because Caddy has no
# cert for the name until DNS points here.
probe() { curl -sSk -o /dev/null -m10 -w "$2 -> HTTP %{http_code}\n" --resolve "$1:443:$IP" "https://$1$2" || true; }

deploy_sync() {
	echo "==> Building taijobi-sync for $SYNC_TARGET"
	(cd taijobi-sync-zig && zig build --release=safe -Dtarget="$SYNC_TARGET")
	local bin=taijobi-sync-zig/zig-out/bin/taijobi-sync
	file "$bin" | grep -q 'ELF 64-bit.*x86-64' || die "$bin is not a Linux x86_64 binary — refusing to ship it"

	echo "==> Uploading binary, units, Caddy fragments"
	# COPYFILE_DISABLE: keep macOS xattrs out of the archive (GNU tar warns).
	COPYFILE_DISABLE=1 tar czf - -C "$ROOT" \
		infra/scripts/setup-server.sh \
		infra/systemd/taijobi-sync.service \
		infra/taijobi-sync.caddy \
		infra/taijobi-web.caddy |
		ssh "$VPS" 'rm -rf /root/taijobi-deploy && mkdir -p /root/taijobi-deploy && tar xzf - -C /root/taijobi-deploy'
	scp -q "$bin" "$VPS:/usr/local/bin/taijobi-sync.new"

	ssh "$VPS" SYNC_PORT="$SYNC_PORT" bash <<'REMOTE'
set -euo pipefail
cd /root/taijobi-deploy
# Atomic swap — never leaves a half-written binary.
chmod 0755 /usr/local/bin/taijobi-sync.new
mv /usr/local/bin/taijobi-sync.new /usr/local/bin/taijobi-sync
bash infra/scripts/setup-server.sh

# The main Caddyfile serves other sites — only ever add fragments.
mkdir -p /etc/caddy/conf.d
install -m 0644 infra/taijobi-sync.caddy /etc/caddy/conf.d/taijobi-sync.caddy
install -m 0644 infra/taijobi-web.caddy /etc/caddy/conf.d/taijobi-web.caddy
grep -qF "import conf.d/*.caddy" /etc/caddy/Caddyfile ||
	printf "\n# Per-service fragments\nimport conf.d/*.caddy\n" >>/etc/caddy/Caddyfile
caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile

install -m 0644 infra/systemd/taijobi-sync.service /etc/systemd/system/taijobi-sync.service
systemctl daemon-reload
systemctl enable --quiet taijobi-sync
systemctl restart taijobi-sync
systemctl reload caddy

sleep 1
curl -fsS "http://127.0.0.1:$SYNC_PORT/health" >/dev/null && echo "health: ok" || { journalctl -u taijobi-sync -n 20 --no-pager; exit 1; }
echo -n "VAPID public key: "
curl -fsS "http://127.0.0.1:$SYNC_PORT/push/vapid-public-key" || echo "(push disabled)"
echo
REMOTE
	probe sync.taijobi.com /health
}

deploy_web() {
	echo "==> Building web app"
	./scripts/build-wasm.sh
	(cd taijobi-web && bun install --frozen-lockfile && bun run build)
	[[ -f taijobi-web/build/200.html ]] || die "taijobi-web/build/200.html missing — did the build run?"
	ls taijobi-web/build/*.wasm >/dev/null 2>&1 || die "no .wasm in taijobi-web/build"

	echo "==> Syncing to $VPS:/var/www/taijobi"
	ssh "$VPS" 'mkdir -p /var/www/taijobi/data'
	# --delete so removed assets don't linger — but never into data/: the
	# dictionaries are deployed separately and the build only has 3 of the 5.
	rsync -az --delete --exclude '/data/' taijobi-web/build/ "$VPS:/var/www/taijobi/"
	ssh "$VPS" 'chown -R caddy:caddy /var/www/taijobi 2>/dev/null || true'
	probe taijobi.com /
	probe taijobi.com /home
}

deploy_data() {
	local dir=taijobi-web/static/data
	local files=()
	mkdir -p "$dir"
	for d in "${DICTS[@]}"; do
		if [[ ! -s "$dir/$d.bin" ]]; then
			echo "==> Fetching $d.bin from $DATA_SOURCE"
			curl -fSL --progress-bar "$DATA_SOURCE/$d.bin" -o "$dir/$d.bin.part"
			mv "$dir/$d.bin.part" "$dir/$d.bin"
		fi
		files+=("$dir/$d.bin")
	done
	echo "==> Syncing dictionaries to $VPS:/var/www/taijobi/data"
	ssh "$VPS" 'mkdir -p /var/www/taijobi/data'
	# --delay-updates: upload under temp names, rename at the end, so a client
	# mid-download never sees a truncated file.
	rsync -az --progress --delay-updates "${files[@]}" "$VPS:/var/www/taijobi/data/"
	ssh "$VPS" 'chown -R caddy:caddy /var/www/taijobi/data 2>/dev/null || true; ls -la /var/www/taijobi/data'
}

[[ "$WHAT" == all || "$WHAT" == sync ]] && deploy_sync
[[ "$WHAT" == all || "$WHAT" == web ]] && deploy_web
[[ "$WHAT" == data ]] && deploy_data

echo "==> Deployed ($WHAT) to $VPS"
