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

## Community Packs / Marketplace Decisions

- **Monorepo, not separate repo.** Pack JSON files are tiny (even HSK 6 with 2500
  words is ~200KB). Hundreds of community packs would still be a few MB. No reason
  to split — keeps CI simple, no cross-repo coordination, contributors see full
  context. CODEOWNERS + branch protection handle access control.
- **No separate CDN.** Packs deploy from `static/packs/` alongside the app to
  Cloudflare. The app already fetches `catalog.json` from the same origin.
- **CI auto-generates catalog.** Validate pack JSONs against schema, auto-generate
  `catalog.json` from pack directories, copy into `static/packs/`, deploy with the
  app. Contributors PR a pack, CI handles the rest.
- **v1 → v2 → v3 progression.** v1 (done): static catalog, manually curated. v2:
  PR-based community contributions with CI validation. v3 (earned complexity):
  in-app browse/search/rate, user uploads, categories — only when community
  activity justifies it.

## Phase 5.0 Decisions

- **Dark mode: class-based with FOUC prevention.** TailwindCSS v4 `@custom-variant dark`
  with `.dark` class on `<html>`. Inline script in `app.html` reads localStorage before
  paint to prevent flash. Three modes: Light/Dark/System. System mode listens to
  `prefers-color-scheme` media query.
- **Language detection per card, not per pack.** CSV/apkg imports previously hardcoded
  `language='zh'` and `language_pair='zh-de'`. Now `lang.detect()` runs on each word
  during import. Pack `language_pair` derived from dominant language after all cards are
  inserted. Supports zh/ar/de/en detection.
- **Arabic: RTL + large text, no transliteration.** Arabic script with diacritics (tashkīl)
  already encodes pronunciation — pinyin equivalent not needed. Display uses `dir="rtl"`
  and `text-5xl` in drill for readability of diacritical marks.
- **Vocabulary table LIMIT 200.** 15k-card packs overflow the 512KB JSON buffer in
  `getVocabulary()`. Rather than increasing buffer or adding pagination complexity,
  limit to first 200 rows with a "Erste 200 von N Wörtern" note. Drill still processes
  all cards — this only affects the browse view.
- **Drill batch continuation.** Completion screen now shows remaining due/unread count
  and a "Weiter →" button to immediately load the next batch, avoiding the round-trip
  through the picker.

## Phase 5.2 Decisions

- **WASM stays on the main thread.** Moving libtaijobi.wasm into a Web Worker would
  eliminate jank during the 19MB endict parse and other sync hot spots, but the cost
  is a system-wide refactor: every `wasm.ts` call site becomes async, `$derived(getDueCount())`
  loses its sync simplicity, OPFS handles can't cross threads (so the persistence layer
  moves into the worker too), the DevTools panel + sync WebSocket need RPC layers, and
  drill answer checking gains 1-3ms postMessage latency per keystroke. Pragmatic middle:
  keep WASM on the main thread, throttle progress callbacks to ~30Hz, yield to the event
  loop before/after the sync WASM parse (`scheduler.yield()` with `setTimeout` fallback),
  and write to OPFS *before* `loadEndict()` so the file is durably cached even if the
  parse fails or the user closes the tab. Revisit only if Phase 5.4 (Kindle bulk import)
  or another bulk operation forces the issue. Same call wimg made.
- **Throttle dictionary-download progress callbacks.** Streaming a 19MB file with 16KB
  chunks fires ~1200 progress events; without throttling, Svelte reactivity re-renders
  the progress bar on every chunk and the browser drops frames. `emitProgress()` in
  `dictionary-data.ts` caps callbacks to 33ms intervals (≈30Hz) and force-emits at 0%
  and 100%.
- **Cmd+K palette: in-memory pinyin index, not a SQL column.** Adding a `pinyin_normalized`
  column would mean a v4 schema migration + backfill + sync coordination. Instead,
  `searchIndex.svelte.ts` lazily builds a normalized-pinyin lookup from the cards table
  on first palette open and rebuilds when `data.version()` bumps. Cards are bounded
  (low thousands typical) so a JS pass is cheap. Diacritic normalization is a small
  lookup table (`ā→a`, `ǎ→a`, etc.) ported from `pinyin.zig`.
- **FAQ entries live in `commandPalette.svelte.ts`, not actions.svelte.ts.** Even though
  they're consumed by the action registry, the canonical list lives in the palette
  module so the palette stays self-contained and the actions file imports them. The
  list must be kept in sync with `(app)/about/+page.svelte` — selecting a FAQ entry
  navigates to `/about#faq-id` which auto-opens the matching `<details>` via the
  existing `afterNavigate` hook on the about page.

## Phase 5.x Decisions

- **EN/DE dictionaries via Wiktextract.** Monolingual definitions (not translation pairs).
  Compiled from kaikki.org JSONL per-POS files (noun/verb/adj/adv only — full dump is 6GB).
  Same binary format as CEDICT: magic + count + offset index + sorted entries with binary search.
  Case-insensitive lookup for Latin text. EN: 166k entries (~19MB), DE: ~4.6MB.
- **Dictionaries are installable, not embedded.** Users install from Settings → Wörterbücher.
  Downloaded to OPFS, loaded into WASM persistent allocator on startup. Chinese data + EN + DE
  total ~42MB → bumped persistent allocator to 64MB, WASM max memory to 512MB.
- **Self-assessment mode for long definitions.** Non-CJK cards with translation >50 chars
  skip text input. Show "Aufdecken" → reveal definition → rate 1-4. You can't type
  "The phenomenon of making an unplanned, fortunate discovery..." from memory.
- **Vorziehen (pull-forward).** After finishing due cards, offer cards scheduled within 24h.
  Reviews count toward FSRS. `getUpcomingCards()` query: `next_review > now AND <= now + ahead`.
- **Drill session in sessionStorage, not SQLite.** Ephemeral UI state (card queue, index,
  phase) survives page reload but dies on tab close. iOS won't need it (SwiftUI holds state).
  SQLite would push it through sync — your phone would see your laptop's half-finished drill.
- **Landing page at `/`, app at `/home`.** SvelteKit `(app)` route group. Root layout minimal
  (no WASM init), app layout handles WASM + header + bottom nav. Same pattern as wimg.
- **Renamed `chinese-data.ts` → `dictionary-data.ts`.** OPFS directory `chinese-data` →
  `dictionary-data`. Now holds 5 .bin files (cedict, decomp, strokes, endict, dedict).
  DevTools cleanup removes both old and new directory names for existing users.
- **Pre-release checks in release.sh.** oxfmt + oxlint + svelte-check run before version
  bump. Abort on formatting or type errors.

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
