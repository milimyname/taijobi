#!/usr/bin/env python3
"""Generate minimal test .apkg files for Zig tests.

Creates two files:
  - test_deck_store.apkg   (ZIP with STORE compression)
  - test_deck_deflate.apkg (ZIP with DEFLATE compression)

Each contains a tiny Anki SQLite database with 2 notes.
"""

import sqlite3
import json
import io
import struct
import zlib
import os

OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "libtaijobi", "src", "test_data")


def create_anki_db() -> bytes:
    """Create a minimal Anki SQLite database with 2 notes."""
    buf = io.BytesIO()
    conn = sqlite3.connect(":memory:")
    c = conn.cursor()

    # Anki schema (minimal)
    c.execute("""
        CREATE TABLE col (
            id INTEGER PRIMARY KEY,
            models TEXT NOT NULL DEFAULT '{}'
        )
    """)
    c.execute("""
        CREATE TABLE notes (
            id INTEGER PRIMARY KEY,
            mid INTEGER NOT NULL,
            flds TEXT NOT NULL
        )
    """)

    # Model with fields: 中文, Pinyin, English
    models = {
        "1234567890": {
            "flds": [
                {"name": "中文"},
                {"name": "Pinyin"},
                {"name": "English"},
            ]
        }
    }
    c.execute("INSERT INTO col (id, models) VALUES (1, ?)", (json.dumps(models),))

    # 2 test notes (fields separated by 0x1f)
    sep = "\x1f"
    c.execute(
        "INSERT INTO notes (id, mid, flds) VALUES (1, 1234567890, ?)",
        (f"你好{sep}nǐ hǎo{sep}hello",),
    )
    c.execute(
        "INSERT INTO notes (id, mid, flds) VALUES (2, 1234567890, ?)",
        (f"谢谢{sep}xiè xie{sep}thank you",),
    )

    conn.commit()

    # Dump to bytes
    for line in conn.iterdump():
        buf.write((line + "\n").encode())

    conn.close()

    # Re-create from dump to get actual SQLite file bytes
    conn2 = sqlite3.connect(":memory:")
    conn2.executescript(buf.getvalue().decode())
    conn2.commit()

    # Serialize to bytes
    db_buf = io.BytesIO()
    for chunk in conn2.iterdump():
        db_buf.write((chunk + "\n").encode())
    conn2.close()

    # Actually, we need raw SQLite file bytes, not SQL dump.
    # Write to temp file and read back.
    import tempfile

    tmp = tempfile.NamedTemporaryFile(suffix=".db", delete=False)
    tmp.close()
    try:
        conn3 = sqlite3.connect(tmp.name)
        c3 = conn3.cursor()
        c3.execute("""
            CREATE TABLE col (
                id INTEGER PRIMARY KEY,
                models TEXT NOT NULL DEFAULT '{}'
            )
        """)
        c3.execute("""
            CREATE TABLE notes (
                id INTEGER PRIMARY KEY,
                mid INTEGER NOT NULL,
                flds TEXT NOT NULL
            )
        """)
        c3.execute("INSERT INTO col (id, models) VALUES (1, ?)", (json.dumps(models),))
        c3.execute(
            "INSERT INTO notes (id, mid, flds) VALUES (1, 1234567890, ?)",
            (f"你好{sep}nǐ hǎo{sep}hello",),
        )
        c3.execute(
            "INSERT INTO notes (id, mid, flds) VALUES (2, 1234567890, ?)",
            (f"谢谢{sep}xiè xie{sep}thank you",),
        )
        conn3.commit()
        conn3.close()

        with open(tmp.name, "rb") as f:
            return f.read()
    finally:
        os.unlink(tmp.name)


def make_zip_local_header(filename: bytes, data: bytes, method: int = 0) -> bytes:
    """Create a ZIP local file header + data."""
    if method == 8:  # DEFLATE
        compressed = zlib.compress(data, 6)[2:-4]  # raw deflate (strip zlib header/trailer)
    else:
        compressed = data

    header = struct.pack(
        "<4sHHHHHIIIHH",
        b"PK\x03\x04",  # signature
        20,  # version needed
        0,  # flags
        method,  # compression method (0=store, 8=deflate)
        0,  # mod time
        0,  # mod date
        zlib.crc32(data) & 0xFFFFFFFF,  # crc32
        len(compressed),  # compressed size
        len(data),  # uncompressed size
        len(filename),  # filename length
        0,  # extra field length
    )
    return header + filename + compressed


def make_zip_central_dir(filename: bytes, data: bytes, local_offset: int, method: int = 0) -> bytes:
    """Create a ZIP central directory entry."""
    if method == 8:
        compressed = zlib.compress(data, 6)[2:-4]
    else:
        compressed = data

    entry = struct.pack(
        "<4sHHHHHHIIIHHHHHII",
        b"PK\x01\x02",  # signature
        20,  # version made by
        20,  # version needed
        0,  # flags
        method,  # compression method
        0,  # mod time
        0,  # mod date
        zlib.crc32(data) & 0xFFFFFFFF,
        len(compressed),
        len(data),
        len(filename),
        0,  # extra length
        0,  # comment length
        0,  # disk number start
        0,  # internal attributes
        0,  # external attributes
        local_offset,
    )
    return entry + filename


def make_zip_eocd(cd_offset: int, cd_size: int, num_entries: int) -> bytes:
    """Create a ZIP end of central directory record."""
    return struct.pack(
        "<4sHHHHIIH",
        b"PK\x05\x06",
        0,  # disk number
        0,  # disk with CD
        num_entries,
        num_entries,
        cd_size,
        cd_offset,
        0,  # comment length
    )


def make_apkg(db_bytes: bytes, method: int = 0) -> bytes:
    """Create a minimal .apkg (ZIP) file with the given SQLite database."""
    filename = b"collection.anki2"

    local = make_zip_local_header(filename, db_bytes, method)
    cd_offset = len(local)
    cd = make_zip_central_dir(filename, db_bytes, 0, method)
    eocd = make_zip_eocd(cd_offset, len(cd), 1)

    return local + cd + eocd


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    db_bytes = create_anki_db()

    store_path = os.path.join(OUT_DIR, "test_deck_store.apkg")
    with open(store_path, "wb") as f:
        f.write(make_apkg(db_bytes, method=0))
    print(f"  wrote {store_path} ({os.path.getsize(store_path)} bytes)")

    deflate_path = os.path.join(OUT_DIR, "test_deck_deflate.apkg")
    with open(deflate_path, "wb") as f:
        f.write(make_apkg(db_bytes, method=8))
    print(f"  wrote {deflate_path} ({os.path.getsize(deflate_path)} bytes)")


if __name__ == "__main__":
    main()
