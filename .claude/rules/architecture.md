# Architecture

```
libhanzi (Zig)
├── sqlite3.c (amalgamation, compiled in — no external dep)
├── data/
│   ├── cedict_compiled.bin    CC-CEDICT (124k entries, binary format)
│   └── hanzi_decomp.bin      Make Me a Hanzi radical data (9k chars)
├── src/
│   ├── root.zig        C ABI exports — the public API
│   ├── db.zig          SQLite wrapper + schema + migrations
│   ├── fsrs.zig        FSRS scheduler (pure Zig, default FSRS-5 parameters)
│   ├── pinyin.zig      Tone parsing, diacritic ↔ number, fuzzy matching
│   ├── curriculum.zig  Pack install/remove, lesson queries, progress
│   ├── lexicon.zig     Word collector, language detection, auto-enrichment
│   ├── cedict.zig      Binary search over CC-CEDICT, lookup by hanzi/pinyin
│   ├── decompose.zig   Radical/component tree (Make Me a Hanzi)
│   ├── anki.zig        .apkg import/export (SQLite-based)
│   ├── lang.zig        Language detection (Unicode ranges + heuristics)
│   └── types.zig       Card, Lesson, Pack, ReviewLog structs
│
├── → libhanzi.wasm     (wasm32-freestanding) ← web
└── → libhanzi.a        (aarch64-apple-ios)   ← iOS / macOS

hanzi-web/ (Svelte 5 + TailwindCSS v4)
├── loads libhanzi.wasm
├── OPFS for SQLite persistence (offline, no server)
├── PWA — installable, works fully offline
└── thin shell: UI only, zero business logic

hanzi-ios/ (SwiftUI, future)
├── links libhanzi.a via C ABI
├── SQLite file at ~/Documents/hanzi.db
└── thin shell: UI only, zero business logic
```

## Data Flow

1. All business logic lives in libhanzi (Zig)
2. Web/iOS shells call C ABI functions, receive JSON responses
3. SQLite is the single source of truth, compiled into the library
4. OPFS provides browser persistence (offline, no server)
5. Sync is optional — LWW merge over WebSocket via CF Durable Objects
