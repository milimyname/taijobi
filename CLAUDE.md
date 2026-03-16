# libhanzi — Personal Vocabulary Engine

> libhanzi (Zig) · Svelte 5 web · SwiftUI iOS (future)

*A local-first vocabulary engine for all languages you encounter — with deep
Chinese support, curriculum packs, and spaced repetition.*

Last updated: March 2026

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
| Web persistence | OPFS (SQLite-on-browser, offline)                  |
| iOS UI          | SwiftUI + C ABI (libhanzi.a)                       |
| Sync            | wimg-sync (CF DO + WebSocket + LWW)                |
| Dictionary      | CC-CEDICT + HanDeDict (embedded)                   |
| Decomposition   | Make Me a Hanzi (embedded)                         |
| Content packs   | Static JSON on CDN (Cloudflare Pages)              |
| Tooling         | bun, oxfmt, oxlint, lefthook, conventional commits |

---

## Design System — "Jade Garden"

| Token | Light | Dark | Usage |
|-------|-------|------|-------|
| `primary` | `#2d6a4f` | `#2d6a4f` | Buttons, active nav, progress bars, links |
| `accent` | `#52b788` | `#52b788` | Secondary actions, hover states, icon tints |
| `primary-light` | `#d8f3dc` | — | Light jade tint backgrounds, badges |
| `background` | `#fdfaf1` (warm cream) | `#1a1c1a` (deep green-black) | Page background |
| `surface` | `#ffffff` / `#f7f2e4` | `white/5` / `stone-900/40` | Cards, inputs |
| `border` | `stone-200/60` / `#e7e0d3` | `stone-800` / `emerald-800/20` | Card borders |
| `text-primary` | `stone-900` | `stone-100` | Headings |
| `text-secondary` | `stone-500` | `stone-400` | Body text, descriptions |
| `text-muted` | `stone-400` | `stone-500` | Labels, timestamps |

**Fonts:** Inter (UI), Lexend (display/headings), PingFang SC fallback (Chinese chars)

**Key patterns:**
- Warm cream background (`#fdfaf1`), not pure white
- Cards: `bg-white dark:bg-white/5 border border-primary/5 rounded-xl shadow-sm shadow-primary/5`
- Bottom nav: fixed, backdrop-blur, 4 tabs (Today/Library/Insights/Settings)
- Progress bars: `bg-primary h-2 rounded-full`
- Chinese characters: `text-4xl font-light` in cards, `text-6xl` in drill
- Buttons: `bg-primary text-white font-semibold rounded-lg shadow-md shadow-primary/20`
- Section headings: `text-[11px] font-bold uppercase tracking-[0.2em] text-stone-400`
- Material Symbols Outlined icons (weight 300, no fill by default)

---

## Detailed Documentation

Split into `.claude/rules/` for context efficiency:

- `architecture.md` — full architecture diagram, file tree, data flow
- `schema.md` — complete SQLite schema (all tables + indexes)
- `c-abi.md` — all C ABI function signatures by phase
- `phases.md` — all phase details (0-6), goals, tasks, success criteria
- `data-sources.md` — content pack sources, licenses, wimg copy table
- `decisions.md` — decision log (taijobi lessons, open questions, timeline)
