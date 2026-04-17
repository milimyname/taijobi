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

## Phase 6.2 Decisions

- **Cloudflare Workers, not a VPS.** The 128 MB Worker memory cap looks scary
  until you write down the actual MCP budget: WASM code (~1 MB) + SQLite
  instance (~5 MB) + FBA scratch (~1 MB) + compact persist allocator (16 MB)
  = ~23 MB total. Fits 5× over. Worker gives us free-tier hosting, CF edge
  latency, no new ops, and the MCP server lives inside the existing
  `taijobi-sync` Worker so there's zero new infra. Revisit if multi-user
  load hits the 30 s CPU cap or we need long-lived connections beyond
  SyncRoom's WebSockets.
- **Compact WASM via `-Dmcp=true`, not a runtime flag.** Same Zig source,
  different `PERSIST_SIZE` picked at comptime via
  `@import("build_options").mcp`. A runtime flag would still reserve 128 MB
  of `[N]u8 = undefined` in the binary and the Worker would OOM on
  instantiate regardless. The flag saves 112 MB of reserved memory for a
  one-line change.
- **Hand-rolled JSON-RPC, not `@modelcontextprotocol/sdk`.** The MCP spec's
  HTTP Streamable transport boils down to ~40 lines of `initialize` /
  `tools/list` / `tools/call` / `ping` / `notifications/initialized` dispatch
  over POST. The SDK adds ~100 KB of dependencies for the same shape. Wimg
  proved the hand-rolled path works with Claude Desktop; we follow suit.
- **Durable Object per sync key, not stateless.** Lazily instantiating
  libtaijobi-mcp.wasm on every request would work but waste ~150 ms of cold
  start per tool call. A DO keyed by the sync key keeps the WASM warm +
  caches the decrypted DB between calls. `pullFromSync` runs once at init
  and then every 60 s on reads to stay current with the web client's
  changes; write tools fire-and-forget `state.waitUntil(pushToSync())` so
  the client doesn't wait for the R2 round-trip. `DELETE /mcp` evicts the
  session explicitly.
- **Auth via `Authorization: Bearer <sync-key>`.** The sync key is already
  the root of identity in the existing sync design — no accounts, no
  OAuth. For personal use this is fine; the key grants the same access
  MCP gets. We map `Bearer <key>` to a DO id via `idFromName(key)`.
- **Tool surface: 8, not 24.** Wimg has 24 because its domain (banking,
  categories, debts, goals, undo/redo, accounts) legitimately needs it.
  Taijobi's tool-worthy surface is narrower: pick cards to drill, add
  words, record reviews, import Kindle highlights. Five read + three write
  covers every conversation I can imagine having with Claude about
  taijobi. Add more only when a concrete user flow needs them.
- **Deferred: `lookup_word` (CEDICT), `install_pack`, `query_cards(sql)`.**
  `lookup_word` would add ~9 MB to the compact WASM (CEDICT binary) — not
  worth it when Claude already knows Chinese dictionary definitions.
  `install_pack` needs a pack catalog + download coordination from the
  Worker; tractable but out of scope for v1. `query_cards(sql)` is a
  DevTools-grade escape hatch; gated behind a feature flag when it
  actually ships. These are all single-commit adds once there's demand.
- **No CEDICT in the Worker build.** Cleanest way to respect the 128 MB
  cap without hedging. Leaves room for iOS parity later (where dictionaries
  ship in the app bundle, not in the Worker).

## Phase 6.6 Decisions

- **Server-side cron, not client-side TaskScheduler/Notification.schedule.**
  Browser APIs for scheduling future notifications are either non-existent
  (iOS) or behind flags (Chrome). CF Worker cron triggers are free, trivial,
  and fire regardless of device state.
- **Heartbeat pushed from client, not decrypted from SyncRoom.**
  Decrypting the snapshot to read `last_review_at` would boot a full WASM
  runtime per sub per cron tick. Client pushing a timestamp after each
  review is ~100 bytes, zero WASM, zero crypto.
- **20–28h window relative to last review, not a fixed local time.**
  Timezone-free for v1. Fires ~once daily relative to the user's natural
  cadence. Duolingo does time-of-day personalization later; we start simple.
- **VAPID signing via `crypto.subtle`, no `web-push` npm dep.**
  ~30 LoC. The `web-push` library depends on Node-only crypto modules that
  don't work in Workers; `crypto.subtle.sign('ECDSA')` does.
- **RFC 8291 aes128gcm payload encryption hand-rolled.**
  ~60 LoC using `crypto.subtle.deriveBits` (ECDH) + HKDF + AES-GCM. No
  deps, runs in Workers. The alternative (`web-push` or `push-encryption`)
  both import Node `crypto`.
- **Single PushSubs DO, not one-per-sync-key.**
  Cron needs to iterate every subscription. One DO with a SQLite table is
  scannable in one query; per-key DOs would need a separate index.
- **Banner default-on, push opt-in.**
  Push requires a permission prompt — can't be default. The banner is pure
  UI, zero infra, shows immediately. Both are independently useful and
  complement each other.
- **Email deferred to Phase 7+.**
  Email adds: provider integration (Resend/Postmark), Doppel-Opt-In (German
  law), unsubscribe links, bounce handling, GDPR consent flow. Push + banner
  covers the "reminder when not in app" case without any of that.
- **410 Gone subscription cleanup.**
  When a push endpoint returns 410, the subscription is permanently expired
  (browser unsubscribed, device changed, etc.). The cron deletes it
  immediately so future ticks don't waste cycles on dead endpoints.

## Phase 6.6 — Testing Push Notifications

### Quick test: notification UI only (no server)

```bash
cd taijobi-web && bun run build && bun run preview
```

Open `http://localhost:4173` in Chrome. DevTools → Application → Service
Workers → find the registered SW → type this in the "Push" input:

```json
{"title":"🔥 Test","body":"Streak droht zu brechen","url":"/drill"}
```

Hit Enter → system notification should pop up. Click it → app opens at
`/drill`. If nothing happens: check macOS System Settings → Notifications →
Chrome → Allow.

**Important:** `bun run dev` (port 6173) does NOT register the SW with the
push handler. Always use `build + preview` for push testing.

### Full end-to-end test (subscribe → cron → push)

**Terminal 1 — sync Worker:**

```bash
cd taijobi-sync

# Ensure .dev.vars has the VAPID private key (one line, JWK JSON):
# VAPID_PRIVATE_KEY={"kty":"EC","x":"...","y":"...","crv":"P-256","d":"..."}

bunx wrangler dev --port 8788 --test-scheduled
```

**Terminal 2 — web app (preview mode):**

```bash
cd taijobi-web && bun run build && bun run preview --port 4173
```

**In the browser** at `http://localhost:4173`:

1. Settings → Sync → generate or paste a sync key
2. Settings → Benachrichtigungen → toggle "Streak-Erinnerung" on
3. Allow the browser notification permission prompt
4. Wrangler terminal should show `POST /push/subscribe 200 OK`

**Trigger the cron** (Terminal 3):

```bash
# Set last-review to 24h ago so the cron window matches
SYNC_KEY="your-sync-key-here"
ts=$(($(date +%s) * 1000 - 86400000))

curl -X POST http://localhost:8788/push/heartbeat \
  -H "Authorization: Bearer $SYNC_KEY" \
  -H "Content-Type: application/json" \
  -d "{\"ts\": $ts}"

# Fire the cron manually
curl "http://localhost:8788/__scheduled?cron=0+*+*+*+*"
```

Wrangler terminal should show `[push-cron] Sent 1 pushes: 1 ok, 0 failed`.
A system notification appears on your desktop.

### Testing on prod

```bash
# Fake old heartbeat
curl -X POST https://sync.taijobi.com/push/heartbeat \
  -H "Authorization: Bearer $SYNC_KEY" \
  -H "Content-Type: application/json" \
  -d "{\"ts\": $(($(date +%s) * 1000 - 86400000))}"
```

Can't trigger the cron remotely — wait for the next hourly tick (:00), or
go to Cloudflare Dashboard → Workers → taijobi-sync → Triggers → Cron.

### Testing on iOS

1. Deploy to prod (`git push`, CI deploys)
2. On iPhone Safari: open `https://taijobi.com`
3. Share → "Add to Home Screen" → Add
4. Open the app **from the home screen icon** (not Safari)
5. Settings → Benachrichtigungen → toggle on → Allow
6. iOS requires 16.4+. Safari-in-browser: push is NOT supported.

### Troubleshooting

| Symptom | Fix |
|---|---|
| No notification on desktop | macOS: System Settings → Notifications → [Browser] → Allow. Check Focus/DND mode. |
| `POST /push/subscribe 200` but cron says `0 pushes` | Heartbeat timestamp is outside the 20–28h window. Use `ts=$(($(date +%s) * 1000 - 86400000))`. |
| Cron says `1 failed` with error | Check wrangler logs — usually VAPID key mismatch or `.dev.vars` missing/corrupt. |
| `/__scheduled` returns 404 | Restart wrangler with `--test-scheduled` flag. |
| `"undefined" is not valid JSON` | `.dev.vars` is missing or empty. Write the VAPID private JWK into it. |
| iOS: toggle shows "nicht verfügbar" | App not installed to home screen, or iOS < 16.4. |
| Push works locally but not on prod | Run `wrangler secret put VAPID_PRIVATE_KEY` with the same JWK as `.dev.vars`. |
