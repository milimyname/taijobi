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

### Phase 5.0 — Multi-Language Import + Arabic RTL ✅ DONE

**Goal:** Fix import pipeline for non-Chinese content, add Arabic support.

**libhanzi:** ✅ DONE
- [x] `lang.zig` — add Arabic Unicode range detection (U+0600–06FF, supplements, presentation forms)
- [x] `csv.zig` + `apkg.zig` — detect language per card via `lang.detect()` instead of hardcoding `'zh'`
- [x] `csv.zig` + `apkg.zig` — derive pack `language_pair` from dominant language after import (zh-de/ar-en/de-en/en-en)
- [x] `curriculum.zig` — add `LIMIT 200` to vocabulary query to prevent 512KB JSON buffer overflow on large packs

**taijobi-web:** ✅ DONE
- [x] Drill — Arabic question/reading display: `dir="rtl"`, `text-5xl`, `leading-relaxed`
- [x] Lessons vocab table — adapt headers (Wort/Übersetzung vs Hanzi/Pinyin/Deutsch) based on pack language
- [x] Lessons vocab table — RTL + `text-lg` for Arabic word cells, correct TTS language
- [x] Lexicon — RTL + `text-xl` for Arabic word entries
- [x] `speak.ts` — add ar, ja, ko, fr, es, ru to TTS language map
- [x] Drill completion — show remaining due/unread count, "Weiter →" / "Weiter lesen →" buttons
- [x] Vocabulary table — truncate long translations, show "Erste 200 von N Wörtern" note

### Phase 5.0 — Dictionary Page ✅ DONE

**Goal:** Standalone CC-CEDICT dictionary browser with add-to-lexicon.

**taijobi-web:** ✅ DONE
- [x] Route: `/dictionary` — search bar with debounced CC-CEDICT lookup (hanzi/pinyin/english)
- [x] Results: tappable characters → `/character/[char]`, pinyin, english definition
- [x] TTS speaker button per entry, "Add to Lexicon" button with check mark feedback
- [x] Empty state, no-results state, full dark mode support
- [x] Bottom nav: 4th tab "Wörterbuch" with `dictionary` Material icon
- [x] Layout: pageTitle "Wörterbuch" for `/dictionary` route

### Phase 5.0 — Onboarding + Keyboard Shortcuts + Haptics ✅ DONE

**taijobi-web:** ✅ DONE
- [x] `src/lib/onboarding.svelte.ts` — first-run store, 4-slide intro modal, dismissal persisted to `LS_ONBOARDED`. Settings → "Tour erneut zeigen" can re-trigger via `onboardingStore.reset()`.
- [x] `src/lib/haptics.ts` — `tap`/`medium`/`success`/`error` patterns via `navigator.vibrate()`. Silent no-op on unsupported browsers.
- [x] Drill: haptic on answer reveal (success/error) and on rating buttons (1=error, 2=medium, 3-4=success).
- [x] Global keyboard shortcuts in `(app)/+layout.svelte`: vim-style `g {h,d,l,p,s,w,c,e}` chord navigation, `?` toggles shortcut help modal, `Esc` closes it. Ignored when typing in inputs.
- [x] Inline shortcut help dialog with all bindings (navigation + drill).
- [x] Streaming dictionary download progress (`response.body.getReader()`) — bar animates smoothly during 19MB endict downloads instead of jumping 0→100. Parallel HEAD requests for total size. Integrity check against `Content-Length`.
- [x] PWA icons: `static/icon.svg` + `static/icon-maskable.svg` (jade-green 學 glyph), manifest updated to reference SVG icons (`sizes: any`). Replaces missing PNG references.
- [x] Migrated from Material Symbols Outlined Google Fonts icon font to inline SVG components in `src/lib/icons/` (50 components). Removes cross-origin font dependency, fixes icons not rendering offline.

**5.1 — Stats:** Reviews over time chart, accuracy trends, streak tracking
### Phase 5.2 — Cmd+K Command Palette + Search ✅ DONE

**libtaijobi:** `db.zig` `searchCards()` (SQL LIKE on word/translation/pinyin, exact-then-prefix ordering); `hanzi_search_cards` C ABI export.

**taijobi-web:** `searchCards()` wrapper, lazy in-memory pinyin index with diacritic normalization (`searchIndex.svelte.ts`), palette store, action registry (Navigation/Drill/Daten/Theme/Sync/Onboarding/Danger Zone), `CommandPalette.svelte` Drawer UI with debounced search, sections (Recent/Actions/Karten/Pinyin/Wörterbuch/Zeichen), keyboard nav, recent history in localStorage. Cmd+K / Ctrl+K global shortcut and header search button wired in `(app)/+layout.svelte`.

### Phase 5.3 — DevTools ✅ DONE

**libtaijobi:** `db.rawQuery()` + `db.lastError()` in `db.zig` (JSON-stream arbitrary SQL results, 500-row cap, proper control-char escaping). `hanzi_query` C ABI export in `root.zig` (2MB FBA scratch, `makeLengthPrefixed` result). Exposes `SQLITE_INTEGER/FLOAT/TEXT/BLOB` constants + `sqlite3_column_count/name` in `sqlite_c.zig`.

**taijobi-web:** `features.svelte.ts` feature flag store (persisted to `LS_FEATURES`), `queryRaw(sql)` + `QueryResult` type in `wasm.ts`, `?devtools` URL param flag persisted to `LS_DEVTOOLS`. `DevTools.svelte` gains 2 new tabs — **Flags** (toggles from `featureStore`, empty until `DEFAULT_FEATURES` is populated) and **SQL** (textarea + Run/Schema/Clear buttons, error banner, result table with null-italic cells, 500-row truncation badge, 20-entry history persisted to `LS_SQL_HISTORY`, one-click **TSV export**).

### Phase 5.4 — Kindle import ✅ DONE

**libtaijobi:** `kindle.zig` — pure Zig parser for `My Clippings.txt` (splits on `==========`, handles CRLF + BOM, title-last-`(` for author extraction, localized type detection EN+DE). `hanzi_parse_kindle` export returns JSON array `[{book, author, type, text}]`. Bookmarks skipped server-side. `lexicon.bulkAddWords()` + `hanzi_bulk_add_lexicon` export — single `BEGIN/COMMIT` transaction wrapping N `addWord` calls, counts `{added, skipped, failed}`. Wire format: `[u32 count][u32 len][bytes]…` so word content is byte-transparent.

**taijobi-web:** `/lexicon/import` route. Multi-file drag-and-drop + file picker + "Beispiel-Datei laden" button (fetches `static/examples/my-clippings.txt`). VS Code / Cursor editor-pane fallback (reads `text/plain` item when `files[]` is empty and the payload contains `==========`). Window-level `dragover`/`drop` preventDefault so Chrome doesn't navigate when the drop lands slightly off the zone. Review UI: filter chips (Alle / Kurz ≤5 W. / Lang), select-all toggle, per-entry checkbox with book + word-count footer. Sticky bottom action bar (no `fixed` hack — `sticky bottom-0 -mx-4` bleeds to content edges). `parseClippings()` in `kindle.ts` is a thin wrapper around the Zig export. On success, redirects to `/lexicon?imported=N&skipped=M&books=K` where a dismissable banner reads the query params.

---

## Phase 6 — Native + Community

**6.1 — iOS:** SwiftUI shell linking libhanzi.a, all core screens, push notifications

### Phase 6.2 — MCP Server 🚧 IN PROGRESS

**Goal:** Claude Desktop (and any MCP-capable client) reaches taijobi over HTTP and executes real tool calls against the user's actual lexicon data. Deployed into the existing `taijobi-sync` Worker so there's no new infra.

**libtaijobi:** ✅ DONE
- [x] `build.zig` — `-Dmcp=true` option produces `libtaijobi-mcp.wasm` with a 16 MB `PERSIST_SIZE` instead of 128 MB. Fits inside the 128 MB Cloudflare Worker memory cap without dictionary data (MCP tools don't need endict / dedict / strokes).
- [x] `root.zig` — reads `@import("build_options").mcp` at comptime to pick the allocator size.
- [x] `scripts/build-wasm.sh` — builds both WASMs; compact lands at `taijobi-sync/libtaijobi-mcp.wasm`.
- [x] `.github/workflows/release.yml` — `deploy-sync` job now triggers on `libtaijobi/` + `scripts/` changes, sets up Zig, builds the compact artifact before `wrangler deploy`.

**taijobi-sync:** ✅ DONE so far
- [x] `src/wasm.d.ts` — `*.wasm` → `WebAssembly.Module` declaration (wrangler bundles).
- [x] `src/mcp-wasm.ts` — `WasmInstance` class wrapping the compact WASM. `env` imports match the web client (`js_console_log`, `js_time_ms`). Typed wrappers for the 8 tool exports + crypto (`deriveEncryptionKey`, `encryptField`, `decryptField`) + sync (`getChanges`, `applyChanges`) + `decryptRows` helper.
- [x] `src/mcp-tools.ts` — 8 tools with Zod schemas + handlers:
  - **Read:** `due_count`, `get_due_cards`, `search_cards`, `get_lexicon`, `get_stats`.
  - **Write:** `add_word`, `import_kindle_clippings` (parse → bulk-add composed), `review_card`.
  - `WRITE_TOOL_NAMES` set drives session's push-to-sync behavior.
- [x] `src/mcp-session.ts` — `McpSession` Durable Object, one per sync key. Lazily instantiates WASM on first POST, pulls encrypted rows from `SyncRoom` on init + every 60 s on reads, dispatches JSON-RPC (`initialize` / `tools/list` / `tools/call` / `ping` / `notifications/initialized`). Write tools fire-and-forget `state.waitUntil(pushToSync())` — client response isn't blocked. `DELETE /mcp` evicts the session. Generates `Mcp-Session-Id` on `initialize` and validates on subsequent calls.

**taijobi-sync:** 🚧 remaining
- [ ] `src/index.ts` — add `export { McpSession }`, extend `Bindings`, CORS `allowHeaders` for `Authorization` + `Mcp-Session-Id`, new `POST /mcp` and `DELETE /mcp` routes forwarding to the DO.
- [ ] `wrangler.toml` — add the `MCP_SESSION` DO binding + migration + `.wasm` bundling rule.
- [ ] CLAUDE.md + decisions.md — docs + architectural rationale.
- [ ] Verification: `wrangler dev` + `curl` smoke test, Claude Desktop config snippet.

**Transport:** Streamable HTTP (MCP protocol 2025-03-26). **Auth:** `Authorization: Bearer <sync-key>`. **Implementation:** hand-rolled JSON-RPC (~40 LOC), no `@modelcontextprotocol/sdk` dependency.

**Deferred tools (v2+):** `lookup_word` (needs CEDICT, adds 9 MB to compact WASM), `install_pack` (requires pack catalog coordination), `query_cards(sql)` (dev-only, behind a flag).

**6.3 — Community Packs (Marketplace):** Monorepo — packs live in `packs/` alongside
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

---

## Toolchain — Zig 0.16 upgrade (deferred)

Zig 0.16 shipped in April 2026. Don't upgrade until Phase 6.2 (MCP) is
fully shipped and stable. Reasons:

1. **Zero pressure.** `zig build` + `zig build test` + `zig build -Dmcp=true`
   all pass on 0.15.2. No bug is waiting on a 0.16 fix.
2. **Zig minor bumps routinely break things.** 0.13 → 0.14 changed the `std.io`
   reader/writer API; 0.14 → 0.15 changed allocator interfaces and some build
   system APIs. Expect 0.15 → 0.16 to have similar churn.
3. **Taijobi is tightly coupled to specific Zig APIs.** `std.io.fixedBufferStream`,
   `std.heap.FixedBufferAllocator`, `std.fmt.format` into writers, `@memcpy` +
   `std.mem.readInt`, and build-system bits like `b.addOptions` and
   `wasm_mod.addCSourceFile` — any of these can rename or move.
4. **Pipeline is pinned.** `.github/workflows/release.yml` uses
   `mlugg/setup-zig@v2 version: 0.15.2`. Bumping the toolchain requires every
   dev + CI to bump in lock-step.
5. **Ecosystem-settle tax.** Wait 4–6 weeks for the first patch release
   (0.16.1) that fixes the common migration papercuts before jumping.

**When to actually do it** (dedicated PR, no other changes mixed in):
- After Phase 6.2 lands with no open bugs touching `libtaijobi/`.
- Run `zig fmt --check src/` + `zig build test` + `zig build` + `zig build -Dmcp=true`;
  fix each failure in turn.
- Update the pin in `release.yml` from `0.15.2` → `0.16.x`.
- Allocate ~2 hours; usually takes less but don't rush it.
