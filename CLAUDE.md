# libhanzi — Personal Vocabulary Engine

> libhanzi (Zig) · Svelte 5 web · SwiftUI iOS (future)

*A local-first vocabulary engine for all languages you encounter — with deep
Chinese support, curriculum packs, and spaced repetition.*

Last updated: April 2026 — Phases 0-5.4 complete, Phase 6.2 + 6.6 shipped.

**Recent (April 2026 session):** Google Fonts → system-ui stack, OPFS made optional (Safari LAN-IP compat), global download store (progress survives navigation), DevTools SQL panel + feature flags + TSV export, Kindle `My Clippings.txt` import (Zig parser + bulk transaction), desktop sidebar layout (lg+), Drawer iOS-share-sheet-style scroll lock, custom `+error.svelte`, SW network-first WASM cache + catalog.json, CI dictionary-data workflow split, WASM persistent allocator 64→128 MB, oxlint 0-warnings baseline, rich FAQ formatting (bullets + code blocks + fenced blocks), MCP server (8 tools, compact WASM build, Hono, Cloudflare Worker DO), Web Push streak notifications (VAPID + RFC 8291 aes128gcm + hourly cron), streak-in-danger banner on `/home`, per-platform notification troubleshooting FAQ, **unified /packs catalog (dictionaries + content + imports with kind/tag fields, search + filter chips + sub-grouping, Settings' dict sections removed)**, searchCards LIKEs on cards.context too (Cmd+K + MCP `search_cards` resolve Kindle-source queries like "words from Dune"), DevTools timing fix (queueMicrotask-deferred record + monotonic id — no more `state_unsafe_mutation` / `each_key_duplicate`).

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
- Command palette (Cmd+K): cards (SQL LIKE on word/translation/pinyin/**context** — Kindle-source queries like "Dune" resolve via the `context` column), fuzzy pinyin (in-memory normalized index), CEDICT, actions, recent searches, FAQ entries (navigate to `/about#faq-id` and auto-open the matching `<details>`). FAQ list lives in `lib/commandPalette.svelte.ts` (`FAQ_ENTRIES`) and must stay in sync with the `faqs` array on `/about`. MCP `search_cards` tool shares the same exports, so Claude Desktop inherits context-column search for free.
- DevTools (`?devtools` URL param): 5 tabs — Info (build, WASM memory, DB size, counts), Sync (WS status, key, last sync), Data (OPFS browser + localStorage + danger zone), Flags (toggles from `featureStore` in `lib/features.svelte.ts` — empty until `DEFAULT_FEATURES` in `config.ts` is populated), SQL (`queryRaw` via `hanzi_query` export, 500-row cap, 2MB result buffer, history of 20 persisted to `LS_SQL_HISTORY`).
- Dictionary downloads: managed by `lib/download-state.svelte.ts` — a single global store drives `/packs` + onboarding, so progress bar + success toast survive page navigation. OPFS is optional (Safari on HTTP LAN IPs skips caching but still loads into WASM for the session).
- Kindle import (`/lexicon/import`): client-side parser in `lib/kindle.ts` splits `My Clippings.txt` on `==========` lines, handles CRLF + BOM, localized metadata. Drag-and-drop + file picker support **multiple** files (entries merge). Bulk-insert uses the Zig `hanzi_bulk_add_lexicon` export (one BEGIN/COMMIT transaction + one OPFS save) — critical because per-word `addWord()` would do N OPFS writes. Wire format is length-prefixed (`[u32 count][u32 len][bytes]…`) to accept any byte in highlight text. Sample fixture at `static/examples/my-clippings.txt` exercises EN/DE/ZH — load via the "Beispiel-Datei laden" button.
- MCP server (`taijobi-sync/src/mcp-*.ts`): Claude Desktop — and any MCP client — reaches taijobi over HTTP at `POST https://sync.taijobi.com/mcp` with `Authorization: Bearer <sync-key>`. Runs inside the existing sync Worker, no new deploy target. A separate compact WASM build (`libtaijobi-mcp.wasm`, 16 MB persist allocator) is bundled so the whole thing fits in the 128 MB Worker memory cap without dictionaries. One `McpSession` Durable Object per sync key keeps WASM + decrypted DB warm; writes fire-and-forget push back to `SyncRoom` via `state.waitUntil` so the client response isn't blocked. Hand-rolled JSON-RPC (no SDK dep, ~40 LOC). 8 tools: `due_count`, `get_due_cards`, `search_cards`, `get_lexicon`, `get_stats` (read); `add_word`, `import_kindle_clippings`, `review_card` (write). Add to `~/Library/Application Support/Claude/claude_desktop_config.json`:
  ```json
  { "mcpServers": { "taijobi": {
      "url": "https://sync.taijobi.com/mcp",
      "transport": "http",
      "headers": { "Authorization": "Bearer <sync-key>" }
  }}}
  ```
- Streak banner + Web Push notifications (`StreakBanner.svelte` + `lib/streak-banner.svelte.ts` + `lib/push.svelte.ts` + `taijobi-sync/src/push-*.ts`): amber "Streak droht zu brechen" banner on `/home` when `streak > 0 && reviewed_today === 0`. Web Push via VAPID-signed notifications: client subscribes via `PushManager` with the VAPID public key, server stores subscriptions in a `PushSubs` DO (SQLite-backed, one DO for all subs), hourly cron queries subs in the 20–28h-since-last-review window + 18h no-spam guard, signs VAPID JWTs via `crypto.subtle`, encrypts payloads per RFC 8291 (aes128gcm), POSTs to each endpoint. SW `push` listener shows system notification; `notificationclick` focuses/opens the app at `/drill`. Heartbeat POST after each review keeps the server timestamp fresh. Settings toggle in `/settings` → "Benachrichtigungen" section with toggle switch + iOS install hint. Banner is default-on, push is opt-in (requires permission prompt).
- German UI strings throughout
- Character selection tooltip: select any Chinese character → popup with pinyin,
  definition, and link to `/character/[char]` detail page
- Character grid: `/characters` route — browsable grid, filter by pack/lexicon, search

---

## Detailed Documentation

Split into `.claude/rules/` for context efficiency:

- `architecture.md` — full architecture diagram, file tree, data flow
- `schema.md` — complete SQLite schema (all tables + indexes)
- `c-abi.md` — all C ABI function signatures by phase
- `phases.md` — all phase details (0-6), goals, tasks, success criteria
- `data-sources.md` — content pack sources, licenses, wimg copy table
- `decisions.md` — decision log (taijobi lessons, open questions, timeline)
