#!/usr/bin/env python3
"""
Compile CC-CEDICT text into a binary format for Zig @embedFile().

Binary format:
  Header (8 bytes):
    magic: "CEDI" (4 bytes)
    count: u32 LE (number of entries)

  Offset index (count * 4 bytes):
    offset[i]: u32 LE — byte offset of entry i in the entry table

  Entry table (variable-length entries, sorted by simplified UTF-8):
    Each entry:
      simplified_len: u8
      pinyin_len: u8
      english_len: u16 LE
      simplified: [simplified_len]u8
      pinyin: [pinyin_len]u8
      english: [english_len]u8

Usage:
  python3 scripts/compile-cedict.py /tmp/cedict.txt libtaijobi/data/cedict.bin
"""

import struct
import sys
import re


def parse_pinyin_numbers_to_diacritics(pinyin: str) -> str:
    """Convert numbered pinyin (e.g. 'ni3 hao3') to diacritic pinyin (e.g. 'nǐ hǎo')."""
    tone_marks = {
        'a': ['ā', 'á', 'ǎ', 'à', 'a'],
        'e': ['ē', 'é', 'ě', 'è', 'e'],
        'i': ['ī', 'í', 'ǐ', 'ì', 'i'],
        'o': ['ō', 'ó', 'ǒ', 'ò', 'o'],
        'u': ['ū', 'ú', 'ǔ', 'ù', 'u'],
        'ü': ['ǖ', 'ǘ', 'ǚ', 'ǜ', 'ü'],
    }

    def convert_syllable(syl: str) -> str:
        syl = syl.replace('u:', 'ü').replace('U:', 'Ü')
        if not syl or not syl[-1].isdigit():
            return syl
        tone = int(syl[-1])
        syl = syl[:-1]
        if tone < 1 or tone > 5:
            return syl

        # Find the vowel to place the tone mark on
        # Rules: 'a' or 'e' gets the mark; 'ou' -> mark on 'o'; otherwise last vowel
        lower = syl.lower()
        for v in ['a', 'e']:
            idx = lower.find(v)
            if idx != -1:
                c = syl[idx]
                key = c.lower() if c.lower() in tone_marks else None
                if key:
                    replacement = tone_marks[key][tone - 1]
                    if c.isupper():
                        replacement = replacement.upper()
                    return syl[:idx] + replacement + syl[idx + 1:]

        if 'ou' in lower:
            idx = lower.find('o')
            c = syl[idx]
            replacement = tone_marks['o'][tone - 1]
            if c.isupper():
                replacement = replacement.upper()
            return syl[:idx] + replacement + syl[idx + 1:]

        # Last vowel
        for i in range(len(syl) - 1, -1, -1):
            c = syl[i]
            key = c.lower()
            if key == 'ü':
                key = 'ü'
            if key in tone_marks:
                replacement = tone_marks[key][tone - 1]
                if c.isupper() and key != 'ü':
                    replacement = replacement.upper()
                return syl[:i] + replacement + syl[i + 1:]

        return syl

    syllables = pinyin.split(' ')
    return ' '.join(convert_syllable(s) for s in syllables)


def parse_cedict(path: str) -> list[tuple[str, str, str]]:
    """Parse CC-CEDICT into (simplified, pinyin, english) tuples."""
    entries = []
    with open(path, 'r', encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith('#'):
                continue

            # Format: Traditional Simplified [pinyin] /def1/def2/
            bracket = line.find('[')
            if bracket == -1:
                continue
            bracket_end = line.find(']', bracket)
            if bracket_end == -1:
                continue

            chars_part = line[:bracket].strip()
            parts = chars_part.split(' ', 1)
            if len(parts) < 2:
                continue
            simplified = parts[1].strip()

            pinyin_raw = line[bracket + 1:bracket_end]
            pinyin = parse_pinyin_numbers_to_diacritics(pinyin_raw)

            defs_part = line[bracket_end + 1:].strip()
            # Extract definitions between slashes
            defs = [d for d in defs_part.split('/') if d.strip()]
            english = '; '.join(defs)

            # Truncate english to fit in u16
            if len(english.encode('utf-8')) > 65535:
                english = english[:500]

            entries.append((simplified, pinyin, english))

    return entries


def compile_binary(entries: list[tuple[str, str, str]], out_path: str):
    """Compile entries into binary format."""
    # Sort by simplified (UTF-8 byte order)
    entries.sort(key=lambda e: e[0].encode('utf-8'))

    # Build entry table and offset index
    entry_data = bytearray()
    offsets = []

    for simplified, pinyin, english in entries:
        s_bytes = simplified.encode('utf-8')
        p_bytes = pinyin.encode('utf-8')
        e_bytes = english.encode('utf-8')

        if len(s_bytes) > 255 or len(p_bytes) > 255:
            continue  # Skip entries too long for u8 length fields
        if len(e_bytes) > 65535:
            e_bytes = e_bytes[:65535]

        offsets.append(len(entry_data))

        entry_data += struct.pack('<BBH', len(s_bytes), len(p_bytes), len(e_bytes))
        entry_data += s_bytes
        entry_data += p_bytes
        entry_data += e_bytes

    count = len(offsets)

    with open(out_path, 'wb') as f:
        # Header
        f.write(b'CEDI')
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
        print(f"Usage: {sys.argv[0]} <cedict.txt> <output.bin>")
        sys.exit(1)

    entries = parse_cedict(sys.argv[1])
    print(f"Parsed {len(entries)} entries")
    compile_binary(entries, sys.argv[2])


if __name__ == '__main__':
    main()
