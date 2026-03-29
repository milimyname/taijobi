# Changelog

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
