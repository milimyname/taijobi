# Phases

## Phase 0 — Zig Core + FSRS + Drill MVP

> Equivalent to wimg Phase 0+1. Get the foundation right.

**Goal:** libhanzi.wasm loads in browser, SQLite works in OPFS, FSRS schedules
cards, and you can drill L5 vocabulary.

**libhanzi (Zig):** ✅ DONE
- [x] `build.zig` — compile sqlite3.c, output wasm32-freestanding (677KB WASM)
- [x] `db.zig` — schema v1 (cards, fsrs_state, review_log, meta tables)
- [x] `root.zig` — C ABI: init, close, alloc, free, get_db_ptr, get_db_size, restore_db
- [x] `fsrs.zig` — FSRS-5 scheduler: `schedule()` returns next intervals for each rating,
  `review()` updates card state. Pure Zig, default parameters (~150 lines)
- [x] `types.zig` — Card, FSRSState, ReviewLog structs + hand-written JSON serializer
- [x] `sqlite_c.zig` — manual FFI (wimg pattern, isize destructors)
- [x] Seed data: hardcode Long neu L5 vocabulary (25 cards) in db.zig init

**taijobi-web (Svelte 5):** ✅ DONE
- [x] Scaffold: SvelteKit + TailwindCSS v4 + Vite + Cloudflare adapter
- [x] `wasm.ts` — load libtaijobi.wasm, OPFS persistence (wimg pattern)
- [x] `service-worker.ts` — cache-first WASM, network-first app shell
- [x] COOP/COEP headers in vite.config.ts + `_headers` for CF Pages
- [x] Route: `/drill` — question→answer→complete state machine, rating buttons, keyboard 1-4
- [x] Route: `/` — dashboard with due count + card queue preview
- [x] PWA manifest
- [x] "Jade Garden" design system: warm cream bg, jade green primary, Lexend font
- [ ] Deploy to Cloudflare Pages

**Success criteria:** Drill L5 vocab on phone during Schwebebahn commute.
Works offline. FSRS schedules reviews correctly. It feels good.

**What to copy from wimg:** build.zig structure, wasm_vfs.c, libc_shim.c,
OPFS persistence layer, service worker, PWA setup, vite config, lefthook.yml,
oxfmt/oxlint configs, CI workflow skeleton.

---

## Phase 1 — Personal Lexicon + Multi-Language

> Equivalent to wimg Phase 2.

**Goal:** Quick-add words from reading. Auto-detect language. Chinese words
get enriched from CEDICT. All words reviewable via FSRS.

**libhanzi:**
- [ ] `lexicon.zig` — `addWord()`: detect language, store, create FSRS card
- [ ] `lang.zig` — language detection: CJK Unicode ranges -> "zh", a/o/u/ss -> "de",
  fallback -> "en". Simple heuristics, good enough for 95%.
- [ ] `cedict.zig` — parse CC-CEDICT text format into binary lookup table.
  Binary search by simplified hanzi. Return pinyin + english definition.
- [ ] Schema v2: add `language`, `source_type`, `context` columns to cards table
- [ ] `hanzi_add_word()` C ABI — returns enriched card JSON
- [ ] `hanzi_import_lexicon()` — bulk import JSON array of words
- [ ] `hanzi_get_lexicon()` — list personal words
- [ ] `hanzi_lookup()` — CEDICT dictionary search

**hanzi-web:**
- [ ] Route: `/lexicon` — personal word list with quick-add input at top
- [ ] Quick-add flow: type word -> Enter -> auto-detect + enrich -> added to list
- [ ] Dashboard update: show lexicon count, mix lexicon + pack cards in due count
- [ ] Drill mode: support both Chinese cards (show hanzi -> type deutsch) and
  non-Chinese cards (show word -> type/recall definition)
- [ ] Basic stats: cards reviewed today, accuracy percentage

**Data:**
- [ ] Download CC-CEDICT from mdbg.net, write conversion script
  (`scripts/compile-cedict.py`) to binary format for Zig
- [ ] Optionally also compile HanDeDict (DE-ZH, 84k entries) for German translations

---

## Phase 2 — Content Packs

> Equivalent to wimg Phase 3/3.5.

**Goal:** Download curriculum packs. Browse lessons. Track progress per lesson.

**libhanzi:**
- [ ] `curriculum.zig` — pack install (parse JSON, insert cards + lessons + grammar
  points in one SQLite transaction), remove (delete cards but keep review_log),
  progress calculation (mastered/total per lesson)
- [ ] Schema v3: add `packs`, `lessons`, `grammar_points` tables. Add `pack_id`,
  `lesson_id` to cards.

**Content:**
- [ ] Create Long neu L1-L7 pack JSON manually (from your translation exercises)
- [ ] Create HSK 1 pack from `drkameleon/complete-hsk-vocabulary` (MIT, cleaned JSON)
- [ ] Pack schema spec document (so community can contribute)
- [ ] Host catalog.json + pack files on hanzi.mili-my.name (CF Pages)

**hanzi-web:**
- [ ] Route: `/packs` — catalog browser. Show installed + available packs.
- [ ] Route: `/lessons/:packId` — lesson list with progress bars
- [ ] Route: `/lessons/:packId/:lessonId` — vocabulary list (hanzi, pinyin, deutsch)
- [ ] Dashboard update: lesson progress section, filter drill by pack/lesson
- [ ] Drill mode: option to drill specific lesson or all due cards

---

## Phase 3 — Deep Chinese Features ✅ DONE

> Equivalent to wimg Phase 4A (FinTS).

**Goal:** Character decomposition, stroke animation, translation drills.

**libhanzi:** ✅ DONE
- [x] `decompose.zig` — Make Me a Hanzi dictionary.txt compiled to decomp.bin (~0.8MB).
  Binary search by character. Returns radical, IDS decomposition, components, etymology.
- [x] `strokes.zig` — Make Me a Hanzi graphics.txt compiled to compact strokes.bin (~14MB).
  SVG paths stored as command bytes + u16 coords (not JSON text — 51% smaller).
  Reconstructs SVG path strings + median JSON on demand.
- [x] `pinyin.zig` — normalize pinyin (tone numbers ↔ diacritics, strip spaces, lowercase).
  `pinyinEqual()` for flexible comparison.
- [x] `root.zig` — `hanzi_decompose()` and `hanzi_get_strokes()` C ABI exports.
- [ ] Grammar tracking: deferred — no packs use grammar_tags yet.

**hanzi-web:** ✅ DONE
- [x] Route: `/character/[char]` — hero with 96px character, pinyin, definition.
  Component cards (radical/component labels). Stroke SVG animation from embedded data.
  Related words from user's lexicon. Speaker button.
- [x] Drill mode: direction picker (ZH→DE, DE→ZH, ZH→Pinyin)
- [x] Answer checking in TypeScript: pinyin normalization, German article stripping,
  case-insensitive. Shows correct/incorrect feedback with color coding.
- [x] Tap any Chinese character → navigate to character detail page
  (drill answer view, lexicon list, lesson vocab table)
- [x] Pinyin input: accepts both tone numbers and diacritics
- [ ] Grammar pattern view: deferred — no grammar data in packs yet.

**Build/data:**
- [x] `scripts/compile-decomp.py` + `build-decomp.sh` — download & compile dictionary.txt
- [x] `scripts/compile-strokes.py` + `build-strokes.sh` — download & compile graphics.txt
- [x] `build-wasm.sh` + `build-all.sh` updated to include decomp + strokes
- [x] `.gitignore` updated for decomp.bin + strokes.bin
- [x] `libtaijobi.h` updated with Phase 3 function declarations
- [x] `release.yml` updated with decomp + strokes build steps

---

## Phase 3.5 — CSV/TSV Import + Export ✅ DONE

**Goal:** Import vocabulary from Anki/Quizlet/Memrise CSV exports, export all cards.

**libhanzi:** ✅ DONE
- [x] `csv.zig` — CSV/TSV parser with heuristic column detection (header matching +
  positional fallback), HTML tag stripping, `[sound:]` removal, delimiter auto-detection
- [x] `importCsv()` — creates pack + lesson + cards in one transaction
- [x] `exportCsv()` — tab-separated export of all cards with header row
- [x] `hanzi_import_csv` + `hanzi_export_csv` C ABI exports in root.zig
- [x] `libtaijobi.h` updated with Phase 3.5 declarations

**taijobi-web:** ✅ DONE
- [x] `wasm.ts` — `importCsv()` + `exportCsv()` TypeScript wrappers
- [x] Packs page: drag-and-drop / file picker for .csv/.tsv/.txt files
- [x] CSV preview: detected columns, row count, 5 sample rows in a table
- [x] "Importieren" button → success toast with card count → refresh pack list
- [x] "CSV exportieren" button → downloads `taijobi-export.tsv`
- [x] Toast system (from wimg): `$lib/toast.svelte.ts` + `Toast.svelte` component

**Deferred:**
- [ ] .apkg import — needs ZIP + SQLite-in-JS (Phase 5+)
- [ ] Media import — Phase 5+
- [ ] Field mapping UI — heuristic detection sufficient for v1

---

## Phase 4 — Sync + Multi-Device

> Reuse wimg-sync infrastructure.

**Goal:** Study on phone during commute, review on laptop at home.

- [ ] Reuse wimg-sync (CF DO + WebSocket + LWW merge)
- [ ] Same sync key pattern — no accounts, no signup
- [ ] Same E2E encryption (HKDF-SHA256 + XChaCha20-Poly1305)
- [ ] Review_log syncs too — full history on all devices
- [ ] Real-time WebSocket + echo suppression (2s window)

---

## Phase 5 — Polish

**5.0 — UX:** Onboarding flow, dark mode, keyboard shortcuts, haptic feedback
**5.1 — Stats:** Reviews over time chart, accuracy trends, streak tracking
**5.2 — Search:** Cmd+K palette, SQL LIKE search, fuzzy pinyin search
**5.3 — DevTools:** Feature flags, DevTools panel (WASM/Memory/SQL tabs)
**5.4 — Kindle:** Parse `My Clippings.txt`, auto-detect + bulk import to lexicon

---

## Phase 6 — Native + Community

**6.1 — iOS:** SwiftUI shell linking libhanzi.a, all core screens, push notifications
**6.2 — MCP Server:** Claude integration (add_word, due_count, lookup, study plan)
**6.3 — Community Packs:** GitHub repo, CI validation, auto-publish to CDN
**6.4 — More Languages:** Japanese (JMdict), Korean (KDICT), Wiktextract for any language
**6.5 — Battle Mode (iOS):** Offline multiplayer vocab battles via MultipeerConnectivity
  - Speed Battle: same card, first to answer scores. Timer per round (10s).
  - Shared deck selection, score display, rematch. Cards feed into FSRS.
  - Future game modes: Relay, Vocabulary Poker

---

## Timeline

| Phase | What | Estimate | Prerequisite |
|-------|------|----------|--------------|
| 0 | Zig core + FSRS + Drill MVP | 2 weekends | wimg scaffold copy |
| 1 | Lexicon + CEDICT + Multi-language | 2-3 weekends | Phase 0 validated |
| 2 | Content Packs + Lesson Browser | 2 weekends | Phase 1 |
| 3 | Character decomp + Translation drills | 2-3 weekends | Phase 2 |
| 3.5 | Anki import/export | 1 weekend | Phase 2 |
| 4 | Sync (reuse wimg-sync) | 1 weekend | Phase 2 |
| 5.x | Polish, stats, search, dark mode | Ongoing | Phase 3 |
| 6.x | iOS, MCP, community | Later | Phase 4 |
