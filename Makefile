# taijobi — one place for the everyday commands. Thin wrappers only: the real
# logic stays in scripts/ and infra/scripts/. Run `make` to list targets.
# Modeled on wimg's Makefile; same VPS, same deploy flow.

SHELL := /bin/bash
.DEFAULT_GOAL := help

.PHONY: help dev dev-native wasm web sync ios \
	test check fmt lint \
	deploy deploy-web deploy-sync deploy-data release-patch release-minor

help: ## List targets
	@grep -hE '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | \
		awk -F ':.*## ' '{ printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2 }'

# --- Dev ---------------------------------------------------------------------

dev: ## Web :6173 + Cloudflare Worker sync :8788
	./scripts/dev.sh

dev-native: ## Same, with the native Zig sync server (what the VPS runs)
	TAIJOBI_NATIVE_SYNC=1 ./scripts/dev.sh

# --- Build -------------------------------------------------------------------

wasm: ## Build both WASM variants (web + MCP) and the small dictionaries
	./scripts/build-wasm.sh

web: wasm ## Build the static web app → taijobi-web/build
	cd taijobi-web && bun install --frozen-lockfile && bun run build

sync: ## Build the native sync server for this machine
	cd taijobi-sync-zig && zig build --release=safe

ios: ## Build the XCFramework + regenerate the Xcode project
	./scripts/build-ios.sh
	./scripts/gen-xcodeproj.sh

# --- Quality (same gate as CI) ----------------------------------------------

test: ## libtaijobi (needs the dictionary .bin files), sync server, web
	cd libtaijobi && zig build test
	cd taijobi-sync-zig && zig build test
	cd taijobi-web && bun run test

check: fmt lint test ## fmt + lint + tests + svelte-check
	cd taijobi-web && bun run check

fmt: ## Check formatting (zig fmt + oxfmt)
	zig fmt --check libtaijobi/src libtaijobi/build.zig taijobi-sync-zig/src taijobi-sync-zig/build.zig
	cd taijobi-web && bunx oxfmt --check

lint: ## oxlint
	cd taijobi-web && bunx oxlint

# --- Ship (to the shared Hetzner VPS, `wimg-vps`; override with VPS=…) --------

deploy: ## Build + push sync server and web app
	./scripts/deploy-server.sh

deploy-sync: ## Build + push only the sync server (+ Caddy fragments, unit)
	./scripts/deploy-server.sh sync

deploy-web: ## Build + push only the web app
	./scripts/deploy-server.sh web

deploy-data: ## Push the dictionary .bin files (fetches missing ones)
	./scripts/deploy-server.sh data

release-patch: ## Bump patch, tag, push (CI builds iOS + the GitHub Release)
	./scripts/release.sh patch --push

release-minor: ## Bump minor, tag, push
	./scripts/release.sh minor --push
