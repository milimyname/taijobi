#!/bin/bash
# taijobi server setup — idempotent, runs ON the VPS as root. Called by
# scripts/deploy-server.sh before every sync deploy; safe to re-run.
#
# The box is shared with eigenheim, packsil, wimg and Vaultwarden and was
# provisioned by wimg's infra/scripts/setup-vps.sh (SSH hardening, ufw, Caddy,
# no core dumps). This script deliberately does NOT redo any of that — wimg's
# version resets ufw, which would be disruptive here. It only adds what
# taijobi needs.

set -euo pipefail

[[ $EUID -eq 0 ]] || { echo "Run as root." >&2; exit 1; }
command -v caddy >/dev/null || { echo "Caddy missing — provision the box with wimg's setup-vps.sh first." >&2; exit 1; }

if ! id taijobi &>/dev/null; then
	echo "==> Creating taijobi system user"
	useradd --system --shell /usr/sbin/nologin --home /var/lib/taijobi --create-home taijobi
fi

install -d -o taijobi -g taijobi -m 0750 /var/lib/taijobi
install -d -o root -g taijobi -m 0750 /etc/taijobi
install -d -m 0755 /var/www/taijobi /var/www/taijobi/data

# VAPID key: generated here so the private key never leaves the box. Needs the
# binary, so on the very first deploy this runs after it's installed.
if [[ -x /usr/local/bin/taijobi-sync ]] && ! grep -q '^VAPID_PRIVATE_KEY=' /etc/taijobi/env 2>/dev/null; then
	echo "==> Generating VAPID key into /etc/taijobi/env"
	umask 077
	/usr/local/bin/taijobi-sync gen-vapid >>/etc/taijobi/env
	chown root:taijobi /etc/taijobi/env
	chmod 0640 /etc/taijobi/env
fi
