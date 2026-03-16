# Data Sources & Content Packs

## Embedded (ship with the app)

| Source | Entries | Size | License | Use |
|--------|---------|------|---------|-----|
| CC-CEDICT | 124k | ~5MB | CC BY-SA 4.0 | Chinese auto-enrichment (lookup) |
| HanDeDict | 84k | ~4MB | CC BY-SA | German-Chinese translations |
| Make Me a Hanzi | 9k chars | ~15MB | LGPL | Radical decomposition + stroke order |

## Downloadable Packs (CDN)

| Pack | Source | Entries | License |
|------|--------|---------|---------|
| Long neu L1-L7 | Manual (your course) | ~500 | Your data |
| HSK 1-6 (3.0) | drkameleon/complete-hsk-vocabulary | 11k | MIT |
| HSK + examples | clem109/hsk-vocabulary | varies | Open |
| Tatoeba sentences | tatoeba.org | 48k pairs | CC |
| Wiktionary DE | kaikki.org/wiktextract | huge | CC BY-SA |
| Wiktionary EN | kaikki.org/wiktextract | huge | CC BY-SA |
| FreeDict DE<->EN | freedict.org | varies | GPL |

## What to Copy from wimg (Day 1)

| From wimg | To libhanzi | Changes needed |
|-----------|-------------|----------------|
| `build.zig` | `build.zig` | Rename exports, adjust source files |
| `vendor/sqlite3.c` | `vendor/sqlite3.c` | None |
| `src/root.zig` (skeleton) | `src/root.zig` | New function signatures |
| `wasm_vfs.c` | `wasm_vfs.c` | None |
| `libc_shim.c` | `libc_shim.c` | None |
| `wimg-web/src/lib/wasm.ts` | `hanzi-web/src/lib/wasm.ts` | Rename functions |
| `wimg-web/src/service-worker.ts` | Same | Adjust cache names |
| `wimg-web/vite.config.ts` | Same | Adjust paths |
| `lefthook.yml` | Same | None |
| `.oxfmtrc.json` + `.oxlintrc.json` | Same | None |
| `scripts/release.sh` | Same | Adjust package.json paths |
| `scripts/build-wasm.sh` | Same | Adjust build.zig path |
| `.github/workflows/release.yml` | Same | Adjust job steps |
| OPFS persistence pattern | Same | None |
| PWA manifest pattern | Same | New icons/name |
| Feature flags pattern | Same | New flag keys |
