#!/usr/bin/env python3
"""Extract vocabulary from an Anki .apkg file to TSV.

Usage: python3 scripts/apkg-to-tsv.py deck.apkg [output.tsv]

.apkg = ZIP containing a SQLite DB (collection.anki2 or collection.anki21).
Notes are stored with fields separated by 0x1f (unit separator).
"""

import html
import re
import sqlite3
import sys
import tempfile
import zipfile
from pathlib import Path


def strip_html(s: str) -> str:
    """Remove HTML tags, [sound:...], and decode entities."""
    s = re.sub(r"\[sound:[^\]]*\]", "", s)
    s = re.sub(r"<[^>]+>", "", s)
    s = html.unescape(s)
    return s.strip()


def extract(apkg_path: str, output_path: str | None = None):
    apkg = Path(apkg_path)
    if not apkg.exists():
        print(f"Error: {apkg} not found", file=sys.stderr)
        sys.exit(1)

    with tempfile.TemporaryDirectory() as tmp:
        with zipfile.ZipFile(apkg) as zf:
            zf.extractall(tmp)

        # Find the SQLite database
        db_file = None
        for name in ("collection.anki21", "collection.anki2"):
            candidate = Path(tmp) / name
            if candidate.exists():
                db_file = candidate
                break

        if not db_file:
            print("Error: no collection database found in .apkg", file=sys.stderr)
            sys.exit(1)

        conn = sqlite3.connect(str(db_file))
        cursor = conn.execute("SELECT flds FROM notes")
        rows = cursor.fetchall()
        conn.close()

    if not rows:
        print("No notes found", file=sys.stderr)
        sys.exit(1)

    # Split fields by unit separator (0x1f)
    parsed = []
    for (flds,) in rows:
        fields = [strip_html(f) for f in flds.split("\x1f")]
        # Skip empty rows
        if fields and any(f for f in fields):
            parsed.append(fields)

    # Determine max columns
    max_cols = max(len(r) for r in parsed)

    # Output
    out = Path(output_path) if output_path else apkg.with_suffix(".tsv")
    with open(out, "w", encoding="utf-8") as f:
        for row in parsed:
            # Pad short rows
            while len(row) < max_cols:
                row.append("")
            f.write("\t".join(row) + "\n")

    print(f"{len(parsed)} notes → {out}")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <deck.apkg> [output.tsv]", file=sys.stderr)
        sys.exit(1)
    extract(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else None)
