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

## Phase 1 — Personal Lexicon + Multi-Language ✅ DONE

> Equivalent to wimg Phase 2.

**Goal:** Quick-add words from reading. Auto-detect language. Chinese words
get enriched from CEDICT. All words reviewable via FSRS.

**libhanzi:** ✅ DONE
- [x] `lexicon.zig` — `addWord()`: detect language, store, create FSRS card.
  Also `removeWord()`, `updateWord()`, `getLexicon()`, `getDrillStats()`.
- [x] `lang.zig` — language detection: CJK Unicode ranges -> "zh", a/o/u/ss -> "de",
  fallback -> "en". Simple heuristics, good enough for 95%.
- [x] `cedict.zig` — parse CC-CEDICT text format into binary lookup table.
  Binary search by simplified hanzi. Return pinyin + english definition.
- [x] Schema v2: `language`, `source_type`, `context` columns on cards table
- [x] `hanzi_add_word()` C ABI — returns enriched card JSON
- [x] `hanzi_remove_word()` + `hanzi_update_word()` C ABI
- [x] `hanzi_get_lexicon()` — list personal words with FSRS stats
- [x] `hanzi_lookup()` — CEDICT dictionary search
- [x] `hanzi_get_drill_stats()` — reviewed today, accuracy, totals

**taijobi-web:** ✅ DONE
- [x] Route: `/lexicon` — personal word list with quick-add input at top
- [x] Quick-add flow: type word -> Enter -> auto-detect + enrich -> added to list
- [x] Language filter chips (All, 中文, Deutsch, English)
- [x] Inline edit/delete per word, status indicators (new/review/mastered)
- [x] Dashboard update: show lexicon count, mix lexicon + pack cards in due count
- [x] Drill mode: support both Chinese cards (show hanzi -> type deutsch) and
  non-Chinese cards (show word -> type/recall definition)
- [x] Basic stats: cards reviewed today, accuracy percentage

**Data:** ✅ DONE
- [x] CC-CEDICT compiled to binary format via `scripts/compile-cedict.js`
- [ ] HanDeDict (DE-ZH, 84k entries) — deferred, not yet needed

---

## Phase 2 — Content Packs ✅ DONE

> Equivalent to wimg Phase 3/3.5.

**Goal:** Download curriculum packs. Browse lessons. Track progress per lesson.

**libhanzi:** ✅ DONE
- [x] `curriculum.zig` — pack install (parse JSON, insert cards + lessons + grammar
  points in one SQLite transaction), remove (delete cards but keep review_log),
  progress calculation (mastered/total per lesson). Supports pack upgrading.
- [x] Schema v3: `packs`, `lessons`, `grammar_points` tables. `pack_id`,
  `lesson_id` on cards.

**Content:** ✅ DONE
- [x] Create Long neu L5 pack JSON (from your translation exercises)
- [x] Create HSK 1-6 packs from `drkameleon/complete-hsk-vocabulary` (MIT)
- [x] `catalog.json` + pack files hosted in `static/packs/`

**taijobi-web:** ✅ DONE
- [x] Route: `/packs` — catalog browser. Show installed + available packs.
  Install/remove buttons. CSV/TSV import + .apkg import.
- [x] Route: `/lessons/[packId]` — lesson list with progress bars, expandable
  vocabulary tables (word, pinyin, translation, reps/stability)
- [x] Dashboard update: "Deine Lehrbücher" section with pack progress cards
- [x] Drill mode: drills all due cards (pack + lexicon combined)

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

## Phase 4 — Sync + Multi-Device ✅ DONE

> Reuse wimg-sync infrastructure.

**Goal:** Study on phone during commute, review on laptop at home.

**libhanzi:** ✅ DONE
- [x] `crypto.zig` — HKDF-SHA256 + XChaCha20-Poly1305 (salt: `taijobi-e2e-v1`)
- [x] `db.zig` — `getChangesJson()` + `applyChanges()` with LWW merge
- [x] `root.zig` — 5 sync C ABI exports (get_changes, apply_changes, derive_key, encrypt/decrypt_field)
- [x] Tables synced: cards, fsrs_state, review_log, packs, lessons (NOT meta)

**taijobi-web:** ✅ DONE
- [x] `config.ts` — SYNC_API_URL (auto dev/prod), LS_SYNC_KEY, LS_SYNC_LAST_TS
- [x] `wasm.ts` — sync exports + wrappers + onMutate callback on all mutations
- [x] `sync.ts` — push/pull with E2E encryption, auto-push on mutation
- [x] `sync-ws.svelte.ts` — WebSocket real-time sync, echo suppression, auto-reconnect
- [x] `+layout.svelte` — connectSync/disconnectSync lifecycle
- [x] `/settings` — sync key generation, paste, copy, manual sync, disconnect

**taijobi-sync (CF Worker):** ✅ DONE
- [x] `index.ts` — Hono router, CORS, WS upgrade, push/pull routes
- [x] `sync-room.ts` — Durable Object, R2 LWW merge, WS broadcast, ping/pong
- [x] SHA-256 hashed R2 paths, no raw sync key in storage

---

## Phase 5 — Polish

### Phase 5.0 — Dark Mode ✅ DONE

**Goal:** Full dark mode with Light/Dark/System toggle.

**taijobi-web:** ✅ DONE
- [x] `layout.css` — `@custom-variant dark` for class-based dark mode (TailwindCSS v4)
- [x] `app.html` — inline FOUC prevention script (reads localStorage before paint)
- [x] `theme.svelte.ts` — reactive store: Light/Dark/System, OS media query listener
- [x] `config.ts` — `LS_THEME` localStorage key
- [x] `+layout.svelte` — themeStore.init(), reactive `<meta name="theme-color">`
- [x] `/settings` — "Erscheinungsbild" section with 3-button toggle (Hell/Dunkel/System)
- [x] All 15 `.svelte` files updated with `dark:` Tailwind variants
- [x] Drawer — `:global(.dark)` CSS override for sheet background
- [x] CharTooltip — dark arrow border, dark tooltip background
- [x] Rating buttons — dark variants for red/amber/green/primary backgrounds

**Remaining 5.0:** Onboarding flow, keyboard shortcuts, haptic feedback
**5.1 — Stats:** Reviews over time chart, accuracy trends, streak tracking
**5.2 — Search:** Cmd+K palette, SQL LIKE search, fuzzy pinyin search
**5.3 — DevTools:** Feature flags, DevTools panel (WASM/Memory/SQL tabs)
**5.4 — Kindle:** Parse `My Clippings.txt`, auto-detect + bulk import to lexicon

---

## Phase 6 — Native + Community

**6.1 — iOS:** SwiftUI shell linking libhanzi.a, all core screens, push notifications
**6.2 — MCP Server:** Claude integration (add_word, due_count, lookup, study plan)
**6.3 — Community Packs (Marketplace):** Monorepo — packs live in `packs/` alongside
  the app. Contributors submit packs via PR. CI validates pack JSON against schema,
  auto-generates `catalog.json` from pack directories, copies into `static/packs/`,
  and deploys with the app to Cloudflare. No separate CDN or repo needed.
  Structure: `packs/official/` (taijobi-curated), `packs/community/` (PR contributions),
  `packs/schema.json` (validation schema). The app already fetches catalog.json and
  installs packs — just automate the curation pipeline.
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
