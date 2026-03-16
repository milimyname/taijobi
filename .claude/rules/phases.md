# Phases

## Phase 0 — Zig Core + FSRS + Drill MVP

> Equivalent to wimg Phase 0+1. Get the foundation right.

**Goal:** libhanzi.wasm loads in browser, SQLite works in OPFS, FSRS schedules
cards, and you can drill L5 vocabulary.

**libhanzi (Zig):**
- [ ] `build.zig` — compile sqlite3.c, output wasm32-freestanding
- [ ] `db.zig` — schema v1 (cards, fsrs_state, review_log, meta tables)
- [ ] `root.zig` — C ABI: init, close, alloc, free, get_db_ptr, get_db_size, restore_db
- [ ] `fsrs.zig` — FSRS-5 scheduler: `schedule()` returns next intervals for each rating,
  `review()` updates card state. Pure Zig, default parameters (~150 lines)
- [ ] `types.zig` — Card, FSRSState, ReviewLog structs
- [ ] Seed data: hardcode Long neu L5 vocabulary (~25 cards) in db.zig init

**hanzi-web (Svelte 5):**
- [ ] Scaffold: SvelteKit + TailwindCSS v4 + Vite (copy wimg-web structure)
- [ ] `wasm.ts` — load libhanzi.wasm, OPFS persistence (copy from wimg-web)
- [ ] `service-worker.ts` — offline caching (copy from wimg-web)
- [ ] COOP/COEP headers in vite.config.ts
- [ ] Route: `/drill` — the core review loop
  - Show card (hanzi + pinyin)
  - Input field (type German translation)
  - Reveal answer + rating buttons (Again/Hard/Good/Easy)
  - FSRS intervals shown on each button
  - Progress counter (12/25)
- [ ] Route: `/` — minimal dashboard ("28 cards due", "Start Review" button)
- [ ] PWA manifest + icons
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

## Phase 3 — Deep Chinese Features

> Equivalent to wimg Phase 4A (FinTS).

**Goal:** Character decomposition, translation drills, grammar tracking.

**libhanzi:**
- [ ] `decompose.zig` — load Make Me a Hanzi data. Query: character -> radical tree
  + component meanings. Compile to binary at build time.
- [ ] `pinyin.zig` — tone number <-> diacritic conversion, fuzzy matching, validation
- [ ] Grammar tracking: query review_log by grammar_tag, compute per-pattern accuracy
- [ ] Translation drill mode: compare user input against expected pinyin/deutsch

**hanzi-web:**
- [ ] Route: `/character/:char` — large character display, radical decomposition tree,
  stroke order animation (HanziWriter.js), FSRS status
- [ ] Drill mode: translation direction picker (ZH->DE, DE->ZH, ZH->Pinyin)
- [ ] Grammar pattern view: tap grammar tag -> see all sentences + accuracy stats
- [ ] Tap any character -> navigate to character detail page
- [ ] Pinyin input: accept both tone numbers and diacritics

---

## Phase 3.5 — Anki Compatibility

**Goal:** Import .apkg decks, export to .apkg. Bridge with Anki ecosystem.

- [ ] `anki.zig` — read .apkg (ZIP of SQLite DBs), map to libhanzi card format
- [ ] Export: generate valid .apkg with note types, card templates, media refs
- [ ] Web: drag-and-drop .apkg import, export button in settings, CSV export

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
