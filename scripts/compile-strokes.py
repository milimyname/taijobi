#!/usr/bin/env python3
"""
Compile Make Me a Hanzi graphics.txt into a compact binary format for Zig @embedFile().

Delta-encoded binary format — first coord absolute, rest as i8 deltas per axis.

Header (8 bytes):
  magic: "STRK" (4 bytes)
  count: u32 LE

Offset index (count * 4 bytes):
  offset[i]: u32 LE — byte offset of entry i in the entry table

Entry table (variable-length entries, sorted by character UTF-8):
  Each entry:
    char_len: u8
    stroke_count: u8
    char: [char_len]u8
    For each stroke:
      median_count: u8
      path_data_len: u16 LE
      path_data: [path_data_len]u8 — delta-encoded commands
      median_data: delta-encoded median points

  Path command encoding:
    command_byte:
      0x01 = M (moveto)       — 2 coords (x, y)  — always absolute u16
      0x02 = L (lineto)       — 2 coords (x, y)
      0x03 = Q (quad bezier)  — 4 coords (cx, cy, x, y)
      0x04 = C (cubic bezier) — 6 coords (c1x, c1y, c2x, c2y, x, y)
      0x05 = Z (close)        — 0 coords

    After M command: coords are absolute u16 LE (2 bytes each).
    After L/Q/C commands: each coord is delta from previous same-axis value.
      Delta encoding per coord:
        If delta fits in i8 (-127..127): 1 byte (signed)
        If delta == -128 (escape): impossible, -128 is the escape byte
        Escape 0x80 followed by absolute u16 LE (3 bytes) for outliers

  Median delta encoding:
    First point: u16 LE x, u16 LE y (4 bytes)
    Subsequent points: same delta scheme as path coords (i8 or escape+u16)
"""

import json
import re
import struct
import sys

CMD_MAP = {
    'M': (0x01, 2),
    'L': (0x02, 2),
    'Q': (0x03, 4),
    'C': (0x04, 6),
    'Z': (0x05, 0),
}

ESCAPE = -128  # 0x80 as signed i8


def parse_svg_commands(path_str: str) -> list[tuple[str, list[int]]]:
    """Parse SVG path string into (command_letter, [coords]) tuples."""
    tokens = re.findall(r'[MLQCZ]|[-]?\d+(?:\.\d+)?', path_str)
    commands = []
    i = 0
    while i < len(tokens):
        t = tokens[i]
        if t in CMD_MAP:
            _, n_coords = CMD_MAP[t]
            coords = []
            for _ in range(n_coords):
                i += 1
                if i < len(tokens):
                    coords.append(int(round(float(tokens[i]))))
            commands.append((t, coords))
        i += 1
    return commands


def encode_delta(value: int, prev: int) -> bytes:
    """Encode a coordinate as delta from previous. Returns bytes."""
    delta = value - prev
    if -127 <= delta <= 127:
        return struct.pack('<b', delta)
    else:
        return struct.pack('<bH', ESCAPE, max(0, min(65535, value)))


def encode_absolute_u16(value: int) -> bytes:
    return struct.pack('<H', max(0, min(65535, value)))


def encode_path(commands: list[tuple[str, list[int]]]) -> bytes:
    """Encode path commands with delta encoding."""
    out = bytearray()
    prev_x = 0
    prev_y = 0

    for cmd_letter, coords in commands:
        cmd_byte = CMD_MAP[cmd_letter][0]
        out += struct.pack('<B', cmd_byte)

        if cmd_letter == 'Z':
            continue

        if cmd_letter == 'M':
            # M is always absolute
            for j in range(0, len(coords), 2):
                x, y = coords[j], coords[j + 1]
                out += encode_absolute_u16(x)
                out += encode_absolute_u16(y)
                prev_x, prev_y = x, y
        else:
            # L, Q, C — delta encode pairs (x, y)
            for j in range(0, len(coords), 2):
                x, y = coords[j], coords[j + 1]
                out += encode_delta(x, prev_x)
                out += encode_delta(y, prev_y)
                prev_x, prev_y = x, y

    return bytes(out)


def encode_medians(points: list[list]) -> bytes:
    """Delta-encode median points."""
    out = bytearray()
    if not points:
        return bytes(out)

    # First point absolute
    x0, y0 = int(round(points[0][0])), int(round(points[0][1]))
    out += encode_absolute_u16(x0)
    out += encode_absolute_u16(y0)

    prev_x, prev_y = x0, y0
    for pt in points[1:]:
        x, y = int(round(pt[0])), int(round(pt[1]))
        out += encode_delta(x, prev_x)
        out += encode_delta(y, prev_y)
        prev_x, prev_y = x, y

    return bytes(out)


def parse_graphics(path: str) -> list[dict]:
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
            entries.append({
                'character': character,
                'strokes': obj.get('strokes', []),
                'medians': obj.get('medians', []),
            })
    return entries


def compile_binary(entries: list[dict], out_path: str):
    entries.sort(key=lambda e: e['character'].encode('utf-8'))

    entry_data = bytearray()
    offsets = []

    for e in entries:
        c = e['character'].encode('utf-8')
        strokes = e['strokes']
        medians = e['medians']

        if len(c) > 255 or len(strokes) > 255:
            continue

        offsets.append(len(entry_data))

        # char_len, stroke_count
        entry_data += struct.pack('<BB', len(c), len(strokes))
        entry_data += c

        for si in range(len(strokes)):
            commands = parse_svg_commands(strokes[si])
            median_pts = medians[si] if si < len(medians) else []

            path_binary = encode_path(commands)
            median_binary = encode_medians(median_pts)

            pt_count = min(255, len(median_pts))

            # median_count, path_data_len(u16), median_data_len(u16)
            entry_data += struct.pack('<BHH', pt_count, len(path_binary), len(median_binary))
            entry_data += path_binary
            entry_data += median_binary

    count = len(offsets)

    with open(out_path, 'wb') as f:
        f.write(b'STRK')
        f.write(struct.pack('<I', count))
        for off in offsets:
            f.write(struct.pack('<I', off))
        f.write(entry_data)

    total_size = 8 + count * 4 + len(entry_data)
    print(f"Compiled {count} entries -> {out_path}")
    print(f"Total size: {total_size / 1024 / 1024:.1f} MB")


def main():
    if len(sys.argv) < 3:
        print(f"Usage: {sys.argv[0]} <graphics.txt> <output.bin>")
        sys.exit(1)

    entries = parse_graphics(sys.argv[1])
    print(f"Parsed {len(entries)} entries")
    compile_binary(entries, sys.argv[2])


if __name__ == '__main__':
    main()
