# SQLite Schema (v3)

Fresh databases are created at v3. Older DBs get migrated via sequential
`ALTER TABLE` steps (see **Schema Evolution** below). `db.zig` is the
authoritative source — this file is a summary.

```sql
CREATE TABLE cards (
  id            TEXT PRIMARY KEY,
  word          TEXT NOT NULL,
  language      TEXT NOT NULL DEFAULT 'zh',
  pinyin        TEXT,
  translation   TEXT,
  grammar_tags  TEXT DEFAULT '[]',
  sentences     TEXT DEFAULT '[]',
  decomposition TEXT,
  source_type   TEXT NOT NULL DEFAULT 'seed',  -- 'seed' | 'lexicon' | 'pack'
  pack_id       TEXT,
  lesson_id     TEXT,
  context       TEXT,                          -- Kindle highlight source / free-form
  first_seen_at INTEGER,                       -- v2: unread-tracking for "new" cards
  deleted       INTEGER DEFAULT 0,             -- v3: soft-delete so sync can propagate tombstones
  created_at    INTEGER NOT NULL,
  updated_at    INTEGER NOT NULL
);

CREATE TABLE fsrs_state (
  card_id       TEXT PRIMARY KEY REFERENCES cards(id),
  difficulty    REAL NOT NULL DEFAULT 5.0,
  stability     REAL NOT NULL DEFAULT 0.0,
  reps          INTEGER NOT NULL DEFAULT 0,
  lapses        INTEGER NOT NULL DEFAULT 0,
  last_review   TEXT,
  next_review   TEXT,
  updated_at    INTEGER NOT NULL
);

CREATE TABLE review_log (
  id              TEXT PRIMARY KEY,
  card_id         TEXT NOT NULL REFERENCES cards(id),
  rating          INTEGER NOT NULL,            -- 1 Again / 2 Hard / 3 Good / 4 Easy
  review_date     TEXT NOT NULL,
  time_ms         INTEGER,
  old_stability   REAL,
  new_stability   REAL,
  updated_at      INTEGER NOT NULL
);

CREATE TABLE packs (
  id            TEXT PRIMARY KEY,
  name          TEXT NOT NULL,
  version       INTEGER NOT NULL,
  language_pair TEXT NOT NULL,                 -- e.g. 'zh-de', 'ar-en', 'de-en'
  word_count    INTEGER NOT NULL DEFAULT 0,
  installed_at  INTEGER NOT NULL,
  deleted       INTEGER DEFAULT 0,             -- v3: soft-delete
  updated_at    INTEGER NOT NULL
);

CREATE TABLE lessons (
  id          TEXT PRIMARY KEY,
  pack_id     TEXT NOT NULL REFERENCES packs(id),
  title       TEXT,
  sort_order  INTEGER NOT NULL,
  updated_at  INTEGER NOT NULL
);

CREATE TABLE grammar_points (
  id          TEXT PRIMARY KEY,
  pack_id     TEXT,
  explanation TEXT,
  examples    TEXT DEFAULT '[]',
  updated_at  INTEGER NOT NULL
);

CREATE TABLE meta (
  key   TEXT PRIMARY KEY,
  value TEXT NOT NULL
);

CREATE INDEX idx_cards_language ON cards(language);
CREATE INDEX idx_cards_pack ON cards(pack_id);
CREATE INDEX idx_cards_source ON cards(source_type);
CREATE INDEX idx_fsrs_next ON fsrs_state(next_review);
CREATE INDEX idx_revlog_card ON review_log(card_id);
CREATE INDEX idx_revlog_date ON review_log(review_date);
```

## Schema Evolution

Fresh DBs are seeded at v3 directly; the migration path below only runs
for users on older DBs.

- **v1 (Phase 0):** cards, fsrs_state, review_log, meta — seed data only.
- **v1.1 (Phase 1):** `language`, `source_type`, `context` columns added to cards.
- **v1.2 (Phase 2):** `packs`, `lessons`, `grammar_points` tables; `pack_id`, `lesson_id` on cards.
- **v2 (Phase 1.5):** `ALTER TABLE cards ADD COLUMN first_seen_at INTEGER` — enables the `/home` "unread" section distinguishing truly-new cards from due-but-seen ones.
- **v3 (Phase 4 — sync):** `ALTER TABLE cards ADD COLUMN deleted INTEGER DEFAULT 0` + same for `packs`. Soft-delete is required so a device that deletes a card on laptop still propagates the tombstone to phone via LWW merge — a hard DELETE would just re-sync from the other device.

All tables carry `updated_at` from v1 for LWW sync merge.

## Sync

Tables synced via wimg-sync (`db.getChangesJson` / `db.applyChanges`):

- `cards`, `fsrs_state`, `review_log`, `packs`, `lessons`

NOT synced (app-local):

- `meta`, `grammar_points`

## `tag` is derived, not stored

Packs don't have a `tag` column. The client computes it:

- Catalog lookup by `id` → `tag` from `catalog.json`
- Fallback for orphans (imports, MCP-created packs, future community) → `'personal'`

This keeps the schema untouched when the Phase 6.3 community system ships
— packs authored locally vs. pulled from the catalog share the same
storage.

## Pack `language_pair` vs. per-card `language`

- Pack `language_pair` is a metadata hint set by the pack author (or
  derived from dominant language on .apkg imports). Pack-level display
  uses this (UI chips, drill language filter).
- Per-card `language` is detected from the word's script at insert time
  (`lang.detect` in `lexicon.zig`, `apkg.zig`, `curriculum.zig`). This
  is authoritative for TTS voice selection + `/characters` grouping.

These can legitimately disagree — e.g. an HSK pack declared `zh-en` that
contains some romanised entries → pack stays `zh-en`, the stray cards
get `language='en'`.
