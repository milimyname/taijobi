#!/usr/bin/env bun
/**
 * Compile Make Me a Hanzi graphics.txt into a compact binary format for Zig @embedFile().
 *
 * Delta-encoded binary format — first coord absolute, rest as i8 deltas per axis.
 *
 * Usage: bun scripts/compile-strokes.js <graphics.txt> <output.bin>
 */

import { readFileSync, writeFileSync } from "node:fs";

const CMD_MAP: Record<string, [number, number]> = {
  M: [0x01, 2],
  L: [0x02, 2],
  Q: [0x03, 4],
  C: [0x04, 6],
  Z: [0x05, 0],
};

const ESCAPE = -128; // 0x80 as signed i8

/**
 * Parse SVG path string into [command_letter, coords[]] tuples.
 */
function parseSvgCommands(pathStr) {
  const tokens = pathStr.match(/[MLQCZ]|[-]?\d+(?:\.\d+)?/g) || [];
  const commands = [];
  let i = 0;
  while (i < tokens.length) {
    const t = tokens[i];
    if (t in CMD_MAP) {
      const nCoords = CMD_MAP[t][1];
      const coords = [];
      for (let j = 0; j < nCoords; j++) {
        i++;
        if (i < tokens.length) {
          coords.push(Math.round(parseFloat(tokens[i])));
        }
      }
      commands.push([t, coords]);
    }
    i++;
  }
  return commands;
}

/**
 * Encode a coordinate as delta from previous. Returns Uint8Array.
 */
function encodeDelta(value, prev) {
  const delta = value - prev;
  if (delta >= -127 && delta <= 127) {
    const buf = new ArrayBuffer(1);
    new DataView(buf).setInt8(0, delta);
    return new Uint8Array(buf);
  } else {
    const clamped = Math.max(0, Math.min(65535, value));
    const buf = new ArrayBuffer(3);
    const dv = new DataView(buf);
    dv.setInt8(0, ESCAPE);
    dv.setUint16(1, clamped, true); // LE
    return new Uint8Array(buf);
  }
}

/**
 * Encode absolute u16 LE.
 */
function encodeAbsoluteU16(value) {
  const clamped = Math.max(0, Math.min(65535, value));
  const buf = new ArrayBuffer(2);
  new DataView(buf).setUint16(0, clamped, true);
  return new Uint8Array(buf);
}

/**
 * Encode path commands with delta encoding. Returns Uint8Array.
 */
function encodePath(commands) {
  const parts = [];
  let prevX = 0;
  let prevY = 0;

  for (const [cmdLetter, coords] of commands) {
    const cmdByte = CMD_MAP[cmdLetter][0];
    parts.push(new Uint8Array([cmdByte]));

    if (cmdLetter === "Z") {
      continue;
    }

    if (cmdLetter === "M") {
      for (let j = 0; j < coords.length; j += 2) {
        const x = coords[j];
        const y = coords[j + 1];
        parts.push(encodeAbsoluteU16(x));
        parts.push(encodeAbsoluteU16(y));
        prevX = x;
        prevY = y;
      }
    } else {
      // L, Q, C — delta encode pairs (x, y)
      for (let j = 0; j < coords.length; j += 2) {
        const x = coords[j];
        const y = coords[j + 1];
        parts.push(encodeDelta(x, prevX));
        parts.push(encodeDelta(y, prevY));
        prevX = x;
        prevY = y;
      }
    }
  }

  return concatUint8Arrays(parts);
}

/**
 * Delta-encode median points. Returns Uint8Array.
 */
function encodeMedians(points) {
  if (!points || points.length === 0) {
    return new Uint8Array(0);
  }

  const parts = [];

  // First point absolute
  const x0 = Math.round(points[0][0]);
  const y0 = Math.round(points[0][1]);
  parts.push(encodeAbsoluteU16(x0));
  parts.push(encodeAbsoluteU16(y0));

  let prevX = x0;
  let prevY = y0;
  for (let i = 1; i < points.length; i++) {
    const x = Math.round(points[i][0]);
    const y = Math.round(points[i][1]);
    parts.push(encodeDelta(x, prevX));
    parts.push(encodeDelta(y, prevY));
    prevX = x;
    prevY = y;
  }

  return concatUint8Arrays(parts);
}

/**
 * Concatenate multiple Uint8Arrays into one.
 */
function concatUint8Arrays(arrays) {
  let totalLen = 0;
  for (const a of arrays) {
    totalLen += a.length;
  }
  const result = new Uint8Array(totalLen);
  let offset = 0;
  for (const a of arrays) {
    result.set(a, offset);
    offset += a.length;
  }
  return result;
}

/**
 * Write a u32 LE to a Uint8Array.
 */
function writeU32LE(value) {
  const buf = new ArrayBuffer(4);
  new DataView(buf).setUint32(0, value, true);
  return new Uint8Array(buf);
}

/**
 * Parse graphics.txt (NDJSON) into entries.
 */
function parseGraphics(path: string) {
  const text = readFileSync(path, "utf-8");
  const entries = [];

  for (const line of text.split("\n")) {
    const trimmed = line.trim();
    if (!trimmed) continue;
    let obj;
    try {
      obj = JSON.parse(trimmed);
    } catch {
      continue;
    }
    const character = obj.character || "";
    if (!character) continue;
    entries.push({
      character,
      strokes: obj.strokes || [],
      medians: obj.medians || [],
    });
  }

  return entries;
}

/**
 * Compile entries into binary format and write to output file.
 */
function compileBinary(entries: any[], outPath: string) {
  // Sort by UTF-8 bytes of character
  entries.sort((a, b) => {
    const aBytes = new TextEncoder().encode(a.character);
    const bBytes = new TextEncoder().encode(b.character);
    const minLen = Math.min(aBytes.length, bBytes.length);
    for (let i = 0; i < minLen; i++) {
      if (aBytes[i] !== bBytes[i]) return aBytes[i] - bBytes[i];
    }
    return aBytes.length - bBytes.length;
  });

  const entryParts = [];
  const offsets = [];
  let entryDataLen = 0;

  for (const e of entries) {
    const charBytes = new TextEncoder().encode(e.character);
    const strokes = e.strokes;
    const medians = e.medians;

    if (charBytes.length > 255 || strokes.length > 255) {
      continue;
    }

    offsets.push(entryDataLen);

    // char_len, stroke_count
    const header = new Uint8Array([charBytes.length, strokes.length]);
    entryParts.push(header);
    entryDataLen += header.length;

    entryParts.push(charBytes);
    entryDataLen += charBytes.length;

    for (let si = 0; si < strokes.length; si++) {
      const commands = parseSvgCommands(strokes[si]);
      const medianPts = si < medians.length ? medians[si] : [];

      const pathBinary = encodePath(commands);
      const medianBinary = encodeMedians(medianPts);

      const ptCount = Math.min(255, medianPts.length);

      // median_count(u8), path_data_len(u16 LE), median_data_len(u16 LE)
      const strokeHeader = new ArrayBuffer(5);
      const dv = new DataView(strokeHeader);
      dv.setUint8(0, ptCount);
      dv.setUint16(1, pathBinary.length, true);
      dv.setUint16(3, medianBinary.length, true);
      const strokeHeaderBytes = new Uint8Array(strokeHeader);

      entryParts.push(strokeHeaderBytes);
      entryDataLen += strokeHeaderBytes.length;

      entryParts.push(pathBinary);
      entryDataLen += pathBinary.length;

      entryParts.push(medianBinary);
      entryDataLen += medianBinary.length;
    }
  }

  const count = offsets.length;

  // Build final binary: header + offset index + entry data
  const outputParts = [];

  // Magic "STRK"
  outputParts.push(new TextEncoder().encode("STRK"));
  // Count u32 LE
  outputParts.push(writeU32LE(count));
  // Offset index
  for (const off of offsets) {
    outputParts.push(writeU32LE(off));
  }
  // Entry data
  for (const part of entryParts) {
    outputParts.push(part);
  }

  const output = concatUint8Arrays(outputParts);
  writeFileSync(outPath, output);

  const totalSize = output.length;
  console.log(`Compiled ${count} entries -> ${outPath}`);
  console.log(`Total size: ${(totalSize / 1024 / 1024).toFixed(1)} MB`);
}

function main() {
  const args = process.argv.slice(2);
  if (args.length < 2) {
    console.log(`Usage: bun scripts/compile-strokes.ts <graphics.txt> <output.bin>`);
    process.exit(1);
  }

  const entries = parseGraphics(args[0]);
  console.log(`Parsed ${entries.length} entries`);
  compileBinary(entries, args[1]);
}

main();
