# Changelog

## v0.6.20 (2026-04-25)

- fix: link individual hanzi (not whole sentences) from lesson table
- fix: move lesson drill CTA to top of expanded body
- feat: sticky drill CTA inside expanded lesson accordion
- docs: drop tech-stack section + redundant Datenschutz callout
- feat: lexicon delete-with-undo + add/edit feedback via toast
- feat: scroll + highlight imported pack in /packs

## v0.6.19 (2026-04-25)

- fix: /characters empty state acknowledges installed dictionary

## v0.6.18 (2026-04-25)

- fix: drill auto-pull-forward when ?pack= has no due cards
- fix: center empty-state icons reliably (mx-auto block)
- feat: state-aware drill CTA on /lessons/[packId]
- fix: remove default browser focus outline on /dictionary search
- fix: /dictionary stale when ⌘K re-navigates with new ?q=
- fix: dict uninstall reclaims persist arena bytes in-place
- docs: faq entry explaining "gemeistert" + drill scheduling
- feat: arabisch-alphabet community pack
- docs: refresh MCP tool count + switch config snippet to mcp-remote

## v0.6.17 (2026-04-24)

- feat: list_packs + add_lesson_to_pack MCP tools + WS sync toast

## v0.6.16 (2026-04-24)

- fix: MCP write tools silently skipping sync-push

## v0.6.15 (2026-04-24)

- refactor: install_pack takes a single pack_json string, uses shared validator
- fix: install_pack accepts string-encoded arrays + lesson "name" alias

## v0.6.14 (2026-04-24)

- fix: shrink MCP WASM memory footprint to fit Cloudflare Worker 128MB cap

## v0.6.13 (2026-04-24)

- feat: phase 6.3 community packs pipeline + shared validator + /packs export

## v0.6.12 (2026-04-21)

- fix: update isDraggingSheet to reactive state management.
- feat: install_pack MCP tool + per-card language in curriculum + stroke theme

## v0.6.11 (2026-04-19)

- docs: CLAUDE.md + dark-mode contrast on /characters + /character

## v0.6.10 (2026-04-18)

- feat: infinite scroll in lessons + "Alle Zeichen" filter + honest size_mb

## v0.6.9 (2026-04-18)

- feat: deep-link ⌘K card hits into the lesson page + dark-theme + error-button

## v0.6.8 (2026-04-18)

- feat: CommandPalette becomes the universal find-and-do surface
- feat: dictionary uninstall from /packs + CommandPalette stability

## v0.6.7 (2026-04-17)

- fix: format app.css iOS input block
- fix: cross-dict fallback + iOS input zoom + tooltip opacity

## v0.6.6 (2026-04-17)

- docs: CLAUDE.md — unified packs catalog + context-column search
- fix: format issues

## v0.6.5 (2026-04-17)

- feat: unified packs catalog — dictionaries + content + imports
- fix: truncate slowest function name in DevTools WASM tab
- feat: DevTools WASM call timing tab (like wimg)

## v0.6.4 (2026-04-17)

- fix: remove blue focus outline from lexicon quick-add input
- fix: lexicon dark mode — input + word text were black on dark bg
- docs: add push notification testing guide to decisions.md
- docs: mark Phase 6.2 MCP server as ✅ DONE in phases.md
- docs: refresh CLAUDE.md — consolidate session summary

## v0.6.3 (2026-04-17)

- polish: format remaining FAQ answers with bullets
- fix: delay CommandPalette input focus until Drawer animation settles
- polish: fenced code blocks in FAQ + platform-specific MCP config paths
- polish: rich FAQ formatting with bullets, code, and paragraphs

## v0.6.2 (2026-04-17)

- docs: add per-platform notification troubleshooting FAQ
- fix(sync): ECDH public key property + push-cron error logging
- docs: Phase 6.6 streak banner + Web Push — CLAUDE.md, decisions, phases
- feat(sync): PushSubs DO + VAPID push delivery + cron handler (Phase 6.6 commit 4)
- feat: push notification settings toggle + heartbeat wiring (Phase 6.6 commit 3)
- feat: VAPID public key + SW push/click handlers + push store (Phase 6.6 commit 2)
- feat: streak-in-danger banner on /home (Phase 6.6 commit 1)

## v0.6.1 (2026-04-16)

- fix(sync): use new_sqlite_classes for McpSession migration

## v0.6.0 (2026-04-16)

- fix(drawer): capture scroll intent at touchstart, not every frame
- fix(drawer): per-gesture content-scroll lock, iOS share-sheet style
- docs: Phase 6.2 MCP server — CLAUDE.md, decisions, c-abi, /about FAQ
- feat(sync): wire /mcp routes + MCP_SESSION DO binding; docs
- fix(drawer): scroll content first before dragging sheet at mid-snap
- feat(sync): MCP internals — WASM loader, session DO, tool registry
- build(zig): -Dmcp compact WASM target for the MCP server
- fix: bump WASM persistent allocator 64MB → 128MB for endict growth

## v0.5.21 (2026-04-15)

- polish: import summary banner, DevTools TSV export, sidebar scroll, dedup dark: typos

## v0.5.20 (2026-04-15)

- fix: dark-mode landing + drill "Neue Wörter" + custom +error.svelte
- fix(sw): keep offline support for WASM via network-first + cache fallback
- fix(sw): stop caching libtaijobi.wasm so Zig-only rebuilds reach users

## v0.5.19 (2026-04-14)

- fix(/home): drill cards overflow + Today full-width when Lexikon is empty

## v0.5.18 (2026-04-14)

- refactor: move Kindle parser to Zig + fix Chrome drag-drop + VS Code fallback
- docs: note Phase 5.4 Kindle import in CLAUDE.md
- feat: Kindle My Clippings.txt import with one-transaction bulk insert (Phase 5.4)
- polish: dashboard grid on lg, sidebar child-path highlighting, persist devtools
- docs: refresh CLAUDE.md for Phase 5.2 / 5.3 + desktop layout
- feat: desktop-first layout with persistent sidebar nav
- fix(devtools): clearer error when hanzi_query export is missing
- feat: DevTools Flags + SQL panels (Phase 5.3)
- feat(zig): add hanzi_query for DevTools SQL panel
- fix: load Tailwind on root layout — landing page was unstyled
- docs: Phase 5.2 Decisions — Cmd+K palette rationale
- feat: port wheel handler to Drawer for desktop trackpad/mouse parity

## v0.5.17 (2026-04-14)

- fix: CommandPalette scroll — attach Drawer content to scrollable list
- fix: drop Google Fonts + make OPFS optional + global download store

## v0.5.16 (2026-04-08)

- feat: wimg-style 4-tab bottom nav with /more grid
- feat: Cmd+K command palette + FAQ navigation + dark mode fixes

## v0.5.15 (2026-04-07)

- feat: inline icons, onboarding, shortcuts, haptics, About page

## v0.5.14 (2026-03-29)

- fix: upload R2 objects with --remote flag
- fix: correct JSONL filenames in build-all-data.sh

## v0.5.13 (2026-03-29)

- style: fix oxfmt formatting in wrangler.jsonc
- fix: remove duplicate R2 binding from wrangler config
- feat: serve dictionary .bin files from R2 instead of static assets

## v0.5.12 (2026-03-29)

- fix: stream JSONL parsing to avoid OOM on large Wiktextract files

## v0.5.11 (2026-03-29)

- Version bump

## v0.5.10 (2026-03-29)

- fix: update oxfmt stylesheet path after route restructure
- docs: update decisions.md with Phase 5.x decisions
- feat: landing page at /, app routes under (app)/home
- fix: remove unused imports + add pre-release checks to release.sh

## v0.5.9 (2026-03-29)

- style: fix oxfmt formatting in dictionary-data.ts and wasm.ts

## v0.5.8 (2026-03-29)

- fix: drill close button + dictionary add/remove state sync
- docs: update CLAUDE.md with EN/DE dictionaries and new features
- feat: unified dictionary search (ZH + EN + DE) with toasts
- feat: installable EN/DE dictionaries from Settings
- feat: EN/DE dictionary lookup via Wiktextract
- feat: upcoming cards (Vorziehen) + drill self-assessment mode

## v0.5.7 (2026-03-28)

- style: fix oxfmt formatting in chinese-data.ts
- docs: update CLAUDE.md and phases with Phase 5.0 progress
- feat: dedicated /stats page with heatmap, simplify dashboard
- feat: dictionary page with suggestions and add/remove toggle
- feat: drill session persistence, peek-back, and remove card

## v0.5.6 (2026-03-28)

- fix: OPFS write fallback for Chinese data on Safari

## v0.5.5 (2026-03-22)

- fix: graceful fallback for missing WASM exports + SW clone bug

## v0.5.4 (2026-03-22)

- style: fix oxfmt formatting in chinese-data.ts

## v0.5.3 (2026-03-22)

- feat: make Chinese data optional — on-demand download for WASM

## v0.5.2 (2026-03-21)

- style: fix oxfmt formatting in config.ts and theme.svelte.ts

## v0.5.1 (2026-03-21)

- docs: update CLAUDE.md, phases, and decisions for Phase 5.0
- feat: add RTL support and larger text for Arabic content
- feat: add Arabic language detection and TTS support
- fix: limit vocabulary query to 200 rows to prevent buffer overflow
- fix: render Übersetzung as Unicode, truncate long translations
- refactor: use pack language_pair metadata instead of content sampling
- fix: detect language per card in CSV/apkg import instead of hardcoding zh
- fix: detect language from actual content, not hardcoded metadata
- fix: adapt vocab table for non-Chinese packs and show remaining counts
- feat: add dark mode with Light/Dark/System toggle (Phase 5.0)
- style: hide keyboard hints on mobile in drill view

## v0.5.0 (2026-03-20)

- docs: update decisions log and CLAUDE.md for Phase 4
- feat: add multi-device sync with E2E encryption (Phase 4)

## v0.4.10 (2026-03-19)

- style: fix oxfmt formatting in service-worker.ts

## v0.4.9 (2026-03-19)

- Version bump

## v0.4.8 (2026-03-19)

- fix: service worker cache invalidation, loading UX, and stroke Y-flip

## v0.4.7 (2026-03-19)

- fix: convert scripts from JS to TS, use node:fs for Bun 1.3.11 compat

## v0.4.6 (2026-03-19)

- refactor: rewrite all Python scripts to JavaScript (Bun)
- fix: recreate apkg test data and restore STORE/DEFLATE tests

## v0.4.5 (2026-03-19)

- fix: format apkg.zig and TS files to pass CI checks

## v0.4.4 (2026-03-19)

- feat: CSV/TSV import/export, .apkg import, toast system, DevTools panel (Phase 3.5)
- feat: add reading mode (Browse → Study → Drill) and gate DevTools behind ?devtools
- fix: escape JSON control chars and improve drill display for non-Chinese cards

## v0.4.3 (2026-03-18)

- feat: poll for app updates every 5 minutes via SvelteKit version config

## v0.4.2 (2026-03-18)

- fix: ignore unseen dynamic routes in prerender

## v0.4.1 (2026-03-18)

- style: fix oxfmt formatting in wasm.ts

## v0.4.0 (2026-03-17)

- feat: Phase 3 — Deep Chinese Features
- docs: update CLAUDE.md for Phase 2 completion

## v0.3.0 (2026-03-17)

- feat: Phase 2 — Content Packs + Drill Filter + Update System

## v0.2.4 (2026-03-16)

- fix: rename worker to taijobi, fix release artifact path

## v0.2.3 (2026-03-16)

- Version bump

## v0.2.2 (2026-03-16)

- Version bump

## v0.2.1 (2026-03-16)

- style: fix oxfmt formatting

## v0.2.0 (2026-03-16)

- style: fix zig fmt in fsrs.zig

## v0.1.1 (2026-03-16)

- feat: disable SSR, run as client-side SPA
- docs: update CLAUDE.md for Phase 1 completion
- feat: Phase 1 — Personal Lexicon + CEDICT + Multi-Language

## v0.1.0 (2026-03-16)

- feat: Phase 0 — Zig core + FSRS + Drill MVP
- test: write getPlainForm test
- fix: add loading state
- fix: show correct quiz count
- fix: move to next sought word
- fix: update search component
- fix: connect new sought flashcards with new box id
- fix(conj): 起きる
- fix: connect new flashcardBox with existing collection
- fix: add more special cases for conjugation
- fix: apply new feedbacks
- fix: apply new feedbacks
- chore(deps): bump openai from 4.43.0 to 4.61.1
- chore(deps-dev): bump eslint-plugin-svelte from 2.38.0 to 2.44.0
- chore(deps-dev): bump prettier-plugin-tailwindcss from 0.6.1 to 0.6.6
- chore(deps-dev): bump autoprefixer from 10.4.19 to 10.4.20
- chore(deps-dev): bump sveltekit-superforms from 2.15.2 to 2.18.1
- fix: update multipledrawing, toast for non searches, remove romanji
- fix: update font weight
- fix: show toast login for unuser feature
- fix: don't show onboarding on relogin
- fix: games for guests
