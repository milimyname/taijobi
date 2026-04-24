# Content packs

Source of truth for every pack shown in taijobi's `/packs` catalog.

| Path | Who edits it | What it is |
|---|---|---|
| `packs/official/*.json` | Maintainer (requires review) | Curated taijobi content |
| `packs/community/*.json` | Any contributor via PR | Community-submitted content |
| `packs/dictionaries.json` | Maintainer | Dictionary catalog entries (zh/en/de) |
| `packs/schema.json` | Generated — don't hand-edit | JSON Schema for IDE validation |

At build time `scripts/generate-catalog.ts` reads all of the above, validates
them, and writes `taijobi-web/static/packs/{catalog.json, <id>.json}` which are
git-ignored build artifacts.

## Pack file shape

```jsonc
{
  "id": "my-pack",                    // required, matches filename
  "name": "My Pack",                  // required, shown in UI
  "version": 1,                       // required, positive integer
  "language_pair": "zh-en",           // required, "xx" or "xx-yy"
  "description": "Short tagline",     // optional, shown in the catalog
  "lessons": [                        // required, at least one
    {
      "id": "my-pack-01",             // required, `^[a-z0-9][a-z0-9-]*$`
      "title": "Lesson one",          // optional
      "sort_order": 1,                // required, non-negative integer
      "vocabulary": [                 // required, at least one entry
        {
          "word": "爱",                // required
          "pinyin": "ài",             // optional (for Chinese)
          "translation": "to love"    // required
        }
      ]
    }
  ]
}
```

Per-card `language` is detected automatically from each word's script — the
pack-level `language_pair` is metadata only. Chinese, Arabic, German, English
all just work.

## Submitting a community pack

1. Fork the repo.
2. Add your pack file at `packs/community/<your-pack-id>.json` — the filename
   stem must equal `"id"` inside the file.
3. From the repo root:
   ```
   bun scripts/generate-catalog.ts
   ```
   This validates your pack, writes the regenerated schema into `packs/`, and
   updates the gitignored build artifacts so you can preview in
   `cd taijobi-web && bun run dev`. The script has no runtime dependencies —
   just Bun.
4. Commit (the lefthook hook will re-regenerate `packs/schema.json` if needed)
   and open a PR. The `Validate packs` CI workflow re-runs the generator in
   `--check` mode; a green tick means your pack is shape-valid.

A maintainer will review for content (accuracy, license, appropriateness),
then merge. The next release picks it up automatically — no separate deploy.

## Id rules

- Lowercase letters, digits, and dashes only (`^[a-z0-9][a-z0-9-]*$`).
- Must be globally unique across `official/`, `community/`, and
  `dictionaries.json`. The generator fails the build if two packs share an id.
- Filename stem must match the `"id"` field.

## Catalog order

Entries appear in the catalog in filename (alphabetical) order within each tag
group. The `/packs` page groups by tag (Eigene / Wörterbücher / Lehrbücher /
Community) before rendering, so the absolute order in `catalog.json` mostly
affects which pack is on top of its group.

## Licenses

Community packs must declare their source + license in the PR description.
taijobi does not re-license contributor content; you retain copyright over
what you submit. Don't submit packs derived from commercial courses unless
you're the author or have explicit permission.
