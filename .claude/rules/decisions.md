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

## Phase 3 Decisions

- **Stroke data: delta-encoded compact binary, not JSON text.** Make Me a Hanzi
  graphics.txt has SVG paths + median points as JSON text (~29MB raw). Two-stage
  compression: (1) command bytes + u16 coords instead of text → 14MB, (2) delta-
  encoding per axis (i8 deltas, 98.3% fit; 0x80 escape + u16 for outliers) → 9MB.
  69% total reduction. Zig reconstructs SVG path strings on demand. WASM total:
  ~19MB raw, ~11MB gzipped. Service worker caches once, repeat visits instant.
- **Answer checking in TypeScript, not Zig.** Only web needs it for now. Easier
  to iterate. Pinyin normalization (tone numbers ↔ diacritics, strip spaces),
  German article stripping (der/die/das), case-insensitive. "Earned complexity" —
  move to Zig only if iOS needs it too.
- **No grammar tracking UI yet.** grammar_tags column exists but no packs use it.
  Deferred until packs include grammar data.
- **No `hanzi_fuzzy_search`.** CEDICT `hanzi_lookup` handles prefix search. Fuzzy
  pinyin search deferred.
- **Decomp data is small (~0.8MB).** Dictionary metadata only (radical, IDS,
  pinyin, definition, etymology). No stroke graphics in decomp.bin.
- **Stroke SVG coordinate space.** Make Me a Hanzi uses 0-1024 canvas. Stored as
  u16 with +128 offset to handle occasional small negative values. Reconstructed
  as `M x y Q cx cy x y Z` SVG paths.

## Phase 3.5 Decisions

- **JSON control char escaping in `writeJsonString`.** Anki `.apkg` note fields
  can contain raw control characters (e.g. `\x04` EOT, `\x11` DC1) that survive
  HTML stripping. The JSON spec requires all bytes 0x00-0x1F to be escaped as
  `\uXXXX`. Missing escapes caused `JSON.parse` to fail silently, making drill
  show 0 cards after import. Fixed by adding a default arm for `c < 0x20`.
- **Drill display adapts to non-Chinese content.** Imported Anki decks (e.g.
  Neuroanatomy) have long English sentences as card words. Drill now checks
  `hasChinese(text)` instead of just `card.language === 'zh'` for: (1) question
  text sizing (adaptive: `text-lg`/`text-2xl`/`text-4xl` based on length),
  (2) tappable character grid (hidden for non-CJK text).
- **Never silently swallow JSON parse errors.** `getDueCardsFiltered` had a bare
  `catch { return []; }` that made debugging impossible. All catch blocks now log
  the error + first 200 chars of the JSON string.

## Tooling Decisions

- **All scripts in JavaScript (Bun), not Python.** Data compilation scripts
  (compile-cedict, compile-decomp, compile-strokes) and utilities (apkg-to-tsv,
  build-hsk-packs, generate-test-apkg) rewritten from Python to JS. Eliminates
  Python as a build dependency — the toolchain is now Zig + Bun only. Bun's
  built-in `bun:sqlite` and `zlib` cover the same use cases as Python's stdlib.
  Benchmarked ~2.7x faster on generate-test-apkg (28ms vs 75ms). STORE .apkg
  output is byte-identical; DEFLATE differs slightly due to zlib implementations
  but all Zig tests pass with both.

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
