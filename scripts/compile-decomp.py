#!/usr/bin/env python3
"""
Compile Make Me a Hanzi dictionary.txt into a binary format for Zig @embedFile().

Binary format:
  Header (8 bytes):
    magic: "DCMP" (4 bytes)
    count: u32 LE (number of entries)

  Offset index (count * 4 bytes):
    offset[i]: u32 LE — byte offset of entry i in the entry table

  Entry table (variable-length entries, sorted by character UTF-8):
    Each entry:
      char_len: u8
      radical_len: u8
      decomposition_len: u8
      pinyin_len: u8
      definition_len: u16 LE
      etymology_type_len: u8
      etymology_hint_len: u8
      char: [char_len]u8
      radical: [radical_len]u8
      decomposition: [decomposition_len]u8
      pinyin: [pinyin_len]u8
      definition: [definition_len]u8
      etymology_type: [etymology_type_len]u8
      etymology_hint: [etymology_hint_len]u8

Usage:
  python3 scripts/compile-decomp.py /tmp/dictionary.txt libtaijobi/src/decomp.bin
"""

import json
import struct
import sys


def parse_dictionary(path: str) -> list[dict]:
    """Parse Make Me a Hanzi dictionary.txt (NDJSON)."""
    entries = []
    with open(path, 'r', encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                obj = json.loads(line)
            except json.JSONDecodeError:
                continue

            character = obj.get('character', '')
            if not character:
                continue

            radical = obj.get('radical', '')
            decomposition = obj.get('decomposition', '')
            pinyin_list = obj.get('pinyin', [])
            pinyin = ', '.join(pinyin_list) if isinstance(pinyin_list, list) else str(pinyin_list or '')
            definition = obj.get('definition', '') or ''

            # Etymology
            etymology = obj.get('etymology', {}) or {}
            ety_type = etymology.get('type', '') or ''
            ety_hint = etymology.get('hint', '') or ''

            entries.append({
                'character': character,
                'radical': radical,
                'decomposition': decomposition,
                'pinyin': pinyin,
                'definition': definition,
                'etymology_type': ety_type,
                'etymology_hint': ety_hint,
            })

    return entries


def compile_binary(entries: list[dict], out_path: str):
    """Compile entries into binary format."""
    # Sort by character (UTF-8 byte order)
    entries.sort(key=lambda e: e['character'].encode('utf-8'))

    entry_data = bytearray()
    offsets = []

    for e in entries:
        c = e['character'].encode('utf-8')
        r = e['radical'].encode('utf-8')
        d = e['decomposition'].encode('utf-8')
        p = e['pinyin'].encode('utf-8')
        df = e['definition'].encode('utf-8')
        et = e['etymology_type'].encode('utf-8')
        eh = e['etymology_hint'].encode('utf-8')

        # Truncate to fit length fields
        if len(c) > 255 or len(r) > 255 or len(d) > 255 or len(p) > 255:
            continue
        if len(df) > 65535:
            df = df[:65535]
        if len(et) > 255 or len(eh) > 255:
            et = et[:255]
            eh = eh[:255]

        offsets.append(len(entry_data))

        # Header: char_len, radical_len, decomp_len, pinyin_len, def_len(u16), ety_type_len, ety_hint_len
        entry_data += struct.pack('<BBBBHBB',
            len(c), len(r), len(d), len(p), len(df), len(et), len(eh))
        entry_data += c + r + d + p + df + et + eh

    count = len(offsets)

    with open(out_path, 'wb') as f:
        # Header
        f.write(b'DCMP')
        f.write(struct.pack('<I', count))

        # Offset index
        for off in offsets:
            f.write(struct.pack('<I', off))

        # Entry table
        f.write(entry_data)

    print(f"Compiled {count} entries -> {out_path}")
    total_size = 8 + count * 4 + len(entry_data)
    print(f"Total size: {total_size / 1024 / 1024:.1f} MB")


def main():
    if len(sys.argv) < 3:
        print(f"Usage: {sys.argv[0]} <dictionary.txt> <output.bin>")
        sys.exit(1)

    entries = parse_dictionary(sys.argv[1])
    print(f"Parsed {len(entries)} entries")
    compile_binary(entries, sys.argv[2])


if __name__ == '__main__':
    main()
