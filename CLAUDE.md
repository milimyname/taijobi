# libhanzi — Personal Vocabulary Engine

> libhanzi (Zig) · Svelte 5 web · SwiftUI iOS (future)

*A local-first vocabulary engine for all languages you encounter — with deep
Chinese support, curriculum packs, and spaced repetition.*

Last updated: April 2026 — Phases 0-5.4 complete, Phase 6.2 + 6.6 shipped, Phase 6.3 v1 (public marketplace) shipped.

**Recent (April 2026 session):** Google Fonts → system-ui stack, OPFS made optional (Safari LAN-IP compat), global download store (progress survives navigation), DevTools SQL panel + feature flags + TSV export, Kindle `My Clippings.txt` import (Zig parser + bulk transaction), desktop sidebar layout (lg+), Drawer iOS-share-sheet-style scroll lock, custom `+error.svelte`, SW network-first WASM cache + catalog.json, CI dictionary-data workflow split, WASM persistent allocator 64→128 MB, oxlint 0-warnings baseline, rich FAQ formatting (bullets + code blocks + fenced blocks), MCP server (8 tools, compact WASM build, Hono, Cloudflare Worker DO), Web Push streak notifications (VAPID + RFC 8291 aes128gcm + hourly cron), streak-in-danger banner on `/home`, per-platform notification troubleshooting FAQ, **unified /packs catalog (dictionaries + content + imports with kind/tag fields, search + filter chips + sub-grouping, Settings' dict sections removed, `?kind=dictionary` deep-link preselects the chip)**, searchCards LIKEs on cards.context too (Cmd+K + MCP `search_cards` resolve Kindle-source queries like "words from Dune"), DevTools timing fix (queueMicrotask-deferred record + monotonic id — no more `state_unsafe_mutation` / `each_key_duplicate`), **dictionary uninstall from /packs** (`hanzi_unload_chinese/endict/dedict` exports clear data-slice references + delete OPFS, FBA bytes reclaimed on next reload), **⌘K as universal find-and-do surface** — new sections: Zuletzt geübt (`hanzi_get_last_reviewed_card`), Kürzlich (localStorage ring of `/character/*` visits), Hinzufügen (quick-add when no hits), Pakete (catalog fuzzy-match → `/packs#pack-{id}` with scroll + highlight), Drill starten (prefix `drill `/`üben ` → `/drill?pack={id}`), `book:` / `quelle:` / `from:` prefix filters cards by context column, Wörterbuch section now also calls `lookupWord` (EN/DE Wiktionary) with POS badge — `/dictionary` honors `?q=` on mount, **deep-link card hits into lesson pages** (`?lesson=&card=` auto-expands and scrolls; past-LIMIT cards pinned as "Gesuchte Karte" banner via `hanzi_get_card_by_id`), **infinite scroll in /lessons/[packId]** (IntersectionObserver sentinel + `getVocabulary(offset, limit)`), **/characters "Alle Zeichen" filter** (~9500 chars from decomp.bin via `hanzi_list_decomp_chars`, `content-visibility: auto` grid), CommandPalette input height jitter fix (fixed h-11, opacity-toggled close button), iOS input zoom fix (@media hover:none + font-size 16px override), dark-mode contrast pass (`text-primary dark:text-accent` convention for pinyin/accent text; `dark:bg-white/5` added to `/lessons/[packId]` progress + accordion cards; root `@theme` block in `app.css` so `/error` and landing pages get jade primary), cross-dict fallback in `addWord` + empty-array fallback in `hanzi_lookup_word` (German-without-umlauts words like "hinken" now resolve), released v0.6.10, **public `/marketplace` surface (Phase 6.3 v1)** — Anki-style discovery layer for catalog packs at `/marketplace` (search + kind filter chips + sort dropdown: Empfohlen/Neueste/Älteste/A–Z/Z–A/Größte) with per-pack detail at `/marketplace/{id}` (sample-vocab table, lesson list, "Quellen" attribution section). All public pages prerendered into static HTML — no WASM, no Worker invocation per request. **`(public)` route group** holds marketplace + about with a shared slim nav (Marktplatz / Über / App starten →); `/about` moved out of `(app)` so it's SEO-able and shareable, `(app)` sidebar drops the About entry, FAQ details get `scroll-mt-24` so anchored deep-links clear the sticky nav. Catalog gained `added_at` + `sources[]` (CC-CEDICT, Make Me a Hanzi, kaikki.org Wiktextract, drkameleon/complete-hsk-vocabulary with license per source). **Per-pack OG PNG cards** rendered at build time via hand-written SVG → `@resvg/resvg-js` (devDep, runs only in `vite build`, never on Cloudflare runtime) — `/og/default.png` + `/og/{id}.png` prerender into `.svelte-kit/output/prerendered/pages/og/` and serve from CF Pages CDN. **Data layer migrated to SvelteKit remote functions** (`kit.experimental.remoteFunctions: true` + `compilerOptions.experimental.async: true`, Valibot schemas) — `src/lib/marketplace.remote.ts` exposes `prerender(getCatalog)` + `prerender(getPack, { inputs })` consumed via top-level `await getCatalog()` / `await getPack(page.params.id)` in components; `+page.ts` files removed. **`/packs` trimmed** to Installiert + Eigene Pakete (Import) only — discovery routes through `/marketplace`; `?install={id}` deep-link auto-installs then strips the param so Entfernen + refresh doesn't re-install. **Recent-chars store** filters single-grapheme entries on read AND write + cleans up old multi-char data left over from pre-v0.6.20.

---

## Vision

One Zig library — **libhanzi** — that IS the app. Every platform (web, iOS) is
a thin shell around it. No logic duplication. Same FSRS scheduler, same
dictionary lookup, same SQLite queries, everywhere.

Two sources of vocabulary:

1. **Content Packs** (structured) — Lóng neu, HSK, community-contributed decks.
   Downloaded as JSON, curriculum with lessons, sentences, grammar tags.
2. **Personal Lexicon** (unstructured) — words you encounter while reading books
   in German, English, Chinese, or any language. Quick-add, auto-enriched,
   reviewable via FSRS.

Both feed into the same FSRS review system. Formal study and real-world reading
in one place.

Inspired by libghostty and libwimg: the library is the product.

---

## Principles

- **Simplicity above all.** Less code is better code. FSRS in pure Zig, not via
  Rust FFI. SQL LIKE search before FTS5. Keyword matching for language detection
  before ML models.
- **80/20 Pareto.** CC-CEDICT covers ~95% of Chinese lookups. Don't build a
  custom dictionary engine for the remaining 5%.
- **Earned complexity.** Start with hardcoded L5 vocabulary. Add content packs
  when the drill mode is validated. Add sync when you use two devices. Add iOS
  when the web app is daily-driver quality.
- **Library is the product.** Same C ABI pattern as wimg. Svelte is just a renderer.
- **Reuse what works.** Same architecture, tooling, sync infra, CI, release process.
  Don't reinvent anything that wimg already solved.

---

## Tech Stack

| Layer           | Choice                                             |
| --------------- | -------------------------------------------------- |
| Shared core     | Zig 0.15+ + SQLite (amalgamation)                  |
| SRS algorithm   | FSRS-5 (pure Zig)                                  |
| Web UI          | Svelte 5 + TailwindCSS v4                          |
| Web persistence | OPFS (SQLite + dictionary data, offline)            |
| iOS UI          | SwiftUI + C ABI (libhanzi.a)                       |
| Sync            | wimg-sync (CF DO + WebSocket + LWW)                |
| Dictionary (ZH) | CC-CEDICT (124k entries, binary ~8.4MB)              |
| Dictionary (EN) | Wiktextract English (166k entries, binary ~19MB)     |
| Dictionary (DE) | Wiktextract German (binary ~4.6MB)                   |
| Decomposition   | Make Me a Hanzi dictionary.txt (9.5k chars, ~0.8MB) |
| Stroke data     | Make Me a Hanzi graphics.txt (delta-encoded binary ~9MB) |
| Content packs   | Static JSON served by Cloudflare Worker             |
| Hosting         | Cloudflare Workers (taijobi.com)                   |
| Scripts         | Bun (all data compilation + utility scripts)        |
| Tooling         | bun, oxfmt, oxlint, lefthook, conventional commits |

---

## Design System — "Jade Garden"

| Token | Light | Dark | Usage |
|-------|-------|------|-------|
| `primary` | `#195c37` | `#195c37` | Buttons, active nav, progress bars, links |
| `accent` | `#52b788` | `#52b788` | Secondary actions, hover states, icon tints |
| `primary-light` | `#f0fdf4` | — | Light tint backgrounds, badges |
| `background` | `#fefdfb` (warm cream) | `#131f18` (deep green-black) | Page background |
| `surface` | `#f3f5f0` | `white/5` / `slate-800/40` | Cards, inputs |
| `border` | `slate-100` | `white/5` | Card borders |
| `text-primary` | `slate-900` | `slate-100` | Headings |
| `text-secondary` | `slate-500` | `slate-400` | Body text, descriptions |
| `text-muted` | `slate-400` | `slate-500` | Labels, timestamps |

**Fonts:** `system-ui` stack (UI — SF Pro on macOS/iOS, Segoe UI on Windows, Roboto on Android), PingFang SC fallback (Chinese chars). No web-font downloads — works fully offline.

**Routing:** Landing page at `/`, app at `/home` (SvelteKit route group `(app)`)

**Key patterns:**
- Warm cream background (`#fefdfb`), not pure white
- Cards: `bg-white dark:bg-slate-800/40 border border-slate-100 rounded-2xl shadow-sm`
- Navigation: **mobile** uses the fixed 4-tab bottom nav (Suche/Start/Üben/Mehr) — Suche opens the command palette, Mehr (`/more`) is a 2-col grid linking to Stats/Wörterbuch/Pakete/Lexikon/Zeichen/Einstellungen + a wide About card. **Desktop (`lg:`)** replaces the tab bar with a persistent 240px left sidebar holding the full route tree + a ⌘K search button; the outer wrapper widens from 768px → 1080px. Both paths share the same `isActive()` logic in `(app)/+layout.svelte`.
- Dashboard: per-source drill cards (each pack + lexicon), "Alles gemischt" button, minimal today stats + link to /stats
- Drill: session persisted to sessionStorage (survives reload), peek-back at previous card (ArrowLeft), remove lexicon card mid-drill, "Vorziehen" pull-forward for upcoming cards (next 24h)
- Dictionary: unified search across ZH/EN/DE, default suggestions, add/remove toggle per result
- Packs (`/packs`) — unified catalog surface for dictionaries (ZH/EN/DE), content packs (HSK 1-6, Lóng neu), and user imports (.csv/.tsv/.apkg). `static/packs/catalog.json` entries carry `kind: "content" | "dictionary"` + `tag: "official" | "community" | "personal"` + `size_mb` (dicts) / `word_count` (content). UI has search input, kind filter chips (Alle/Wörterbücher/Lehrbücher), sub-grouping (Eigene/Wörterbücher/Lehrbücher/Community), tag badges per row, Entfernen hidden for dicts. Install handler branches on `kind`: dicts call `downloadStore.start(language_pair)`, content fetches `/packs/{id}.json` → `hanzi_install_pack()`. Install-state: dicts read `data.chineseDataLoaded()` / `endictLoaded()` / `dedictLoaded()` (WASM memory), content reads `data.packs()` (SQLite). Imports land as SQLite packs not in catalog — rendered as catalog orphans with `tag: 'personal'`. `BUILTIN_DICTIONARIES` hardcoded in the page so dicts surface even against a stale catalog; fetch uses `cache: 'no-cache'`; SW network-first on `/packs/catalog.json`.
- Drill self-assessment: non-CJK cards with long definitions use reveal-and-rate instead of type-and-check
- Stats (`/stats`): streak + today summary cards, bar chart with period toggle, accuracy trend, rating distribution, 365-day GitHub-style activity heatmap, totals row
- About (`/about`): hero, privacy details, tech stack, full FAQ (auto-opens hash anchors), GitHub link, version footer. Linked from Settings.
- Progress bars: `bg-primary h-2 rounded-full`
- Chinese characters: `text-4xl font-light` in cards, `text-6xl` in drill
- Arabic text: `dir="rtl"`, `text-5xl` in drill, `text-xl` in lexicon/lessons
- Buttons: `bg-primary text-white font-bold rounded-xl shadow-sm`
- Section headings: `text-[11px] font-bold uppercase tracking-wider text-primary`
- Inline SVG icons in `src/lib/icons/` (Material Symbols Outlined paths, self-hosted, no Google Fonts dependency — work fully offline). Each icon is a Svelte 5 component with `class`/`style` props, `width/height="1em"`, `fill="currentColor"`. `Icon.svelte` dispatcher used where the icon name is dynamic.
- Command palette (Cmd+K) — universal find-and-do surface:
  - **Empty state sections**: Zuletzt geübt (most recently reviewed card via `hanzi_get_last_reviewed_card`; routes CJK→`/character/{char}`, pack→`/lessons/{pack}?lesson=&card=`, lexicon→`/lexicon`), Kürzlich (last 10 `/character/*` visits, localStorage via `lib/recent-chars.svelte.ts`), Letzte Suchen, Actions.
  - **Query-driven sections**: Hinzufügen (first-class "+ Zum Lexikon hinzufügen «{query}»" when no other hits), Pakete (catalog fuzzy-match → `/packs#pack-{id}` scrolls + briefly highlights), Drill starten (prefix `drill `/`üben ` suppresses others, lists matching content packs, → `/drill?pack={id}`), Karten (SQL LIKE on word/translation/pinyin/**context** — Kindle-source queries like "Dune" resolve via the `context` column; italic context excerpts under matching rows), Pinyin (fuzzy in-memory normalized index), Wörterbuch (CEDICT + Wiktionary EN/DE via `lookupWord`, POS badge on wiktionary hits, → `/dictionary?q=` for multi-char / non-CJK hits; `/dictionary` reads `?q=` on mount), Zeichen (single-hanzi detail link), FAQ.
  - **Prefix filters**: `book:X` / `quelle:X` / `from:X` filters Karten results client-side by the context column; dismissable "Quelle: X ×" pill renders above Karten.
  - **Input**: fixed `h-11` container, Close button always rendered + opacity-toggled (no layout jitter when typing). Catalog is loaded lazily when the palette opens.
  - FAQ list lives in `lib/commandPalette.svelte.ts` (`FAQ_ENTRIES`) and must stay in sync with the `faqs` array on `/about`. MCP `search_cards` tool shares the same exports, so Claude Desktop inherits context-column search for free.
- DevTools (`?devtools` URL param): 5 tabs — Info (build, WASM memory, DB size, counts), Sync (WS status, key, last sync), Data (OPFS browser + localStorage + danger zone), Flags (toggles from `featureStore` in `lib/features.svelte.ts` — empty until `DEFAULT_FEATURES` in `config.ts` is populated), SQL (`queryRaw` via `hanzi_query` export, 500-row cap, 2MB result buffer, history of 20 persisted to `LS_SQL_HISTORY`).
- Dictionary downloads: managed by `lib/download-state.svelte.ts` — a single global store drives `/packs` + onboarding, so progress bar + success toast survive page navigation. OPFS is optional (Safari on HTTP LAN IPs skips caching but still loads into WASM for the session).
- Kindle import (`/lexicon/import`): client-side parser in `lib/kindle.ts` splits `My Clippings.txt` on `==========` lines, handles CRLF + BOM, localized metadata. Drag-and-drop + file picker support **multiple** files (entries merge). Bulk-insert uses the Zig `hanzi_bulk_add_lexicon` export (one BEGIN/COMMIT transaction + one OPFS save) — critical because per-word `addWord()` would do N OPFS writes. Wire format is length-prefixed (`[u32 count][u32 len][bytes]…`) to accept any byte in highlight text. Sample fixture at `static/examples/my-clippings.txt` exercises EN/DE/ZH — load via the "Beispiel-Datei laden" button.
- MCP server (`taijobi-sync/src/mcp-*.ts`): Claude Desktop — and any MCP client — reaches taijobi over HTTP at `POST https://sync.taijobi.com/mcp` with `Authorization: Bearer <sync-key>`. Runs inside the existing sync Worker, no new deploy target. A separate compact WASM build (`libtaijobi-mcp.wasm`, 16 MB persist allocator + 16 MB FBA) is bundled so the whole thing fits in the 128 MB Worker memory cap without dictionaries. One `McpSession` Durable Object per sync key keeps WASM + decrypted DB warm; writes fire-and-forget push back to `SyncRoom` via `state.waitUntil` so the client response isn't blocked. Hand-rolled JSON-RPC (no SDK dep, ~40 LOC). **11 tools** (6 read + 5 write): `due_count`, `get_due_cards`, `search_cards`, `get_lexicon`, `get_stats`, `list_packs` (read); `add_word`, `import_kindle_clippings`, `review_card`, `install_pack`, `add_lesson_to_pack` (write). `install_pack` accepts a pack JSON from Claude (e.g. OCR'd from a textbook image) → `hanzi_install_pack` → lands in SQLite under the user's sync key with `tag: 'personal'` in `/packs` → syncs privately to other devices. `add_lesson_to_pack` is the non-destructive sibling — for "I forgot these words for the Geld pack" — it appends a lesson to an existing pack, INSERT OR IGNORE on cards so prior FSRS review state is preserved (calling `install_pack` again would `hardDeletePack` first and wipe scheduler state). Tool descriptions tell Claude to call `list_packs` first so it picks the right `pack_id` instead of duplicating. Add to `~/Library/Application Support/Claude/claude_desktop_config.json`:
  ```json
  { "mcpServers": { "taijobi": {
      "command": "npx",
      "args": [
        "mcp-remote",
        "https://sync.taijobi.com/mcp",
        "--header",
        "Authorization: Bearer DEIN-SYNC-SCHLÜSSEL"
      ]
  }}}
  ```
  (`mcp-remote` is a stdio-to-HTTP bridge — Claude Desktop's bundled MCP client speaks stdio, and the Worker speaks Streamable HTTP; running it via `npx mcp-remote ...` is the supported path. The previous `"transport": "http"` form was rejected by Claude Desktop's loader.)
- Streak banner + Web Push notifications (`StreakBanner.svelte` + `lib/streak-banner.svelte.ts` + `lib/push.svelte.ts` + `taijobi-sync/src/push-*.ts`): amber "Streak droht zu brechen" banner on `/home` when `streak > 0 && reviewed_today === 0`. Web Push via VAPID-signed notifications: client subscribes via `PushManager` with the VAPID public key, server stores subscriptions in a `PushSubs` DO (SQLite-backed, one DO for all subs), hourly cron queries subs in the 20–28h-since-last-review window + 18h no-spam guard, signs VAPID JWTs via `crypto.subtle`, encrypts payloads per RFC 8291 (aes128gcm), POSTs to each endpoint. SW `push` listener shows system notification; `notificationclick` focuses/opens the app at `/drill`. Heartbeat POST after each review keeps the server timestamp fresh. Settings toggle in `/settings` → "Benachrichtigungen" section with toggle switch + iOS install hint. Banner is default-on, push is opt-in (requires permission prompt).
- German UI strings throughout
- Character selection tooltip: select any Chinese character → popup with pinyin,
  definition, and link to `/character/[char]` detail page
- Character grid: `/characters` route — browsable grid, filter by pack/lexicon/**Alle Zeichen** (the 9.500-entry decomp set via `hanzi_list_decomp_chars`; chip appears only when the Chinese dict is installed; grid cells use `content-visibility: auto` for smooth scroll). Pinyin under each cell uses `text-primary/70 dark:text-accent` for readability.
- **Dark-mode contrast convention**: primary + accent are the same hex in both themes, but `text-primary` on a dark surface is hard to read. Use `text-primary dark:text-accent` for tinted pinyin / radical labels / highlighted text. `text-slate-900 dark:text-slate-100` for default body/heading text. Always set explicit text colors on `<td>` / `<span>` that might inherit the root default (invisible black on dark).
- **Lessons page**: `/lessons/[packId]` — lesson accordion with infinite-scroll vocab lists. `getVocabulary(lessonId, offset, limit)` + IntersectionObserver sentinel (400px rootMargin) bumps pages of 200 as the user scrolls. `?lesson=&card=` deep-links auto-expand + scroll + highlight; if the card is past the currently-loaded rows, `hanzi_get_card_by_id` pins it at the top as a "Gesuchte Karte" banner with Speak button.

---

## Detailed Documentation

Split into `.claude/rules/` for context efficiency:

- `architecture.md` — full architecture diagram, file tree, data flow
- `schema.md` — complete SQLite schema (all tables + indexes)
- `c-abi.md` — all C ABI function signatures by phase
- `phases.md` — all phase details (0-6), goals, tasks, success criteria
- `data-sources.md` — content pack sources, licenses, wimg copy table
- `decisions.md` — decision log (taijobi lessons, open questions, timeline)
