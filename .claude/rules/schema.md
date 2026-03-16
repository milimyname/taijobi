# SQLite Schema (v1)

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
  source_type   TEXT NOT NULL DEFAULT 'seed',
  pack_id       TEXT,
  lesson_id     TEXT,
  context       TEXT,
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
  rating          INTEGER NOT NULL,
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
  language_pair TEXT NOT NULL,
  word_count    INTEGER NOT NULL DEFAULT 0,
  installed_at  INTEGER NOT NULL,
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

- **v1 (Phase 0):** cards, fsrs_state, review_log, meta — seed data only
- **v2 (Phase 1):** add `language`, `source_type`, `context` columns to cards
- **v3 (Phase 2):** add `packs`, `lessons`, `grammar_points` tables; add `pack_id`, `lesson_id` to cards

All tables include `updated_at` from v1 for future sync (LWW merge).
