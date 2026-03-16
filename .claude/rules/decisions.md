# Decision Log

## Taijobi Legacy — Lessons Applied

| Taijobi mistake | libhanzi fix |
|---|---|
| Cloud database (Supabase/PB) | SQLite compiled into Zig, OPFS on web |
| Backend API routes for every op | C ABI — all logic local, zero network |
| Docker + Fly.io deployment | Static files on Cloudflare Pages (free) |
| Auth system (accounts, sessions) | No auth. Sync key = identity (wimg pattern) |
| 765 commits, mostly infrastructure | Zig core IS the product. Copy proven infra from wimg. |
| Japanese-only, English UI | Multi-language via content packs + personal lexicon |
| No offline | Offline-first. Sync is optional. |
| Stalled rewrite (10 commits) | Same architecture as wimg — proven, not experimental |

## Open Questions

- **Naming:** libhanzi for now. If multi-language takes off -> rename. `taijobi.com` available.
- **Curriculum licensing:** Long neu vocabulary entered manually. HSK is PRC government
  data (MIT-licensed forks exist). Community packs need clear attribution.
- **CEDICT size in WASM:** 124k entries x ~100 bytes = ~12MB. May need lazy loading or
  compressed binary format rather than embedding in WASM memory. Test in Phase 1.
- **FSRS optimizer:** Start with default parameters (good for most users). Add optimizer
  later if review data shows it would help. The scheduler alone is the priority.
- **Sync namespace:** Separate `hanzi-sync` worker or add namespace to `wimg-sync`?
  Separate is cleaner, same code, independent deployment.
- **Word capture while reading:** Start with batch input in app. Kindle import in Phase 5.4.
