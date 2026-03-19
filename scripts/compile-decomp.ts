#!/usr/bin/env bun
/**
 * Compile Make Me a Hanzi dictionary.txt into a binary format for Zig @embedFile().
 *
 * Binary format:
 *   Header (8 bytes):
 *     magic: "DCMP" (4 bytes)
 *     count: u32 LE (number of entries)
 *
 *   Offset index (count * 4 bytes):
 *     offset[i]: u32 LE — byte offset of entry i in the entry table
 *
 *   Entry table (variable-length entries, sorted by character UTF-8):
 *     Each entry:
 *       char_len: u8
 *       radical_len: u8
 *       decomposition_len: u8
 *       pinyin_len: u8
 *       definition_len: u16 LE
 *       etymology_type_len: u8
 *       etymology_hint_len: u8
 *       char: [char_len]u8
 *       radical: [radical_len]u8
 *       decomposition: [decomposition_len]u8
 *       pinyin: [pinyin_len]u8
 *       definition: [definition_len]u8
 *       etymology_type: [etymology_type_len]u8
 *       etymology_hint: [etymology_hint_len]u8
 *
 * Usage:
 *   bun scripts/compile-decomp.js <dictionary.txt> <output.bin>
 */

import { readFileSync, writeFileSync } from "node:fs";

const encoder = new TextEncoder();

function parseDictionary(path: string) {
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

    const radical = obj.radical || "";
    const decomposition = obj.decomposition || "";
    const pinyinList = obj.pinyin;
    const pinyin = Array.isArray(pinyinList)
      ? pinyinList.join(", ")
      : String(pinyinList || "");
    const definition = obj.definition || "";

    const etymology = obj.etymology || {};
    const etymologyType = etymology.type || "";
    const etymologyHint = etymology.hint || "";

    entries.push({
      character,
      radical,
      decomposition,
      pinyin,
      definition,
      etymologyType,
      etymologyHint,
    });
  }

  return entries;
}

function compileBinary(entries, outPath) {
  // Sort by character UTF-8 byte order
  entries.sort((a, b) => {
    const ab = encoder.encode(a.character);
    const bb = encoder.encode(b.character);
    const len = Math.min(ab.length, bb.length);
    for (let i = 0; i < len; i++) {
      if (ab[i] !== bb[i]) return ab[i] - bb[i];
    }
    return ab.length - bb.length;
  });

  const entryBuffers = [];
  const offsets = [];
  let entryDataLen = 0;

  for (const e of entries) {
    const c = encoder.encode(e.character);
    const r = encoder.encode(e.radical);
    const d = encoder.encode(e.decomposition);
    const p = encoder.encode(e.pinyin);
    let df = encoder.encode(e.definition);
    let et = encoder.encode(e.etymologyType);
    let eh = encoder.encode(e.etymologyHint);

    // Truncate to fit length fields
    if (c.length > 255 || r.length > 255 || d.length > 255 || p.length > 255) {
      continue;
    }
    if (df.length > 65535) {
      df = df.slice(0, 65535);
    }
    if (et.length > 255) {
      et = et.slice(0, 255);
    }
    if (eh.length > 255) {
      eh = eh.slice(0, 255);
    }

    offsets.push(entryDataLen);

    // Header: char_len(u8), radical_len(u8), decomp_len(u8), pinyin_len(u8),
    //         def_len(u16 LE), ety_type_len(u8), ety_hint_len(u8)
    const header = new Uint8Array(8);
    header[0] = c.length;
    header[1] = r.length;
    header[2] = d.length;
    header[3] = p.length;
    header[4] = df.length & 0xff;
    header[5] = (df.length >> 8) & 0xff;
    header[6] = et.length;
    header[7] = eh.length;

    const entryLen = 8 + c.length + r.length + d.length + p.length + df.length + et.length + eh.length;
    const buf = new Uint8Array(entryLen);
    let pos = 0;
    buf.set(header, pos); pos += 8;
    buf.set(c, pos); pos += c.length;
    buf.set(r, pos); pos += r.length;
    buf.set(d, pos); pos += d.length;
    buf.set(p, pos); pos += p.length;
    buf.set(df, pos); pos += df.length;
    buf.set(et, pos); pos += et.length;
    buf.set(eh, pos);

    entryBuffers.push(buf);
    entryDataLen += entryLen;
  }

  const count = offsets.length;
  const totalSize = 8 + count * 4 + entryDataLen;
  const output = new Uint8Array(totalSize);
  const view = new DataView(output.buffer);

  // Header
  output[0] = 0x44; // D
  output[1] = 0x43; // C
  output[2] = 0x4d; // M
  output[3] = 0x50; // P
  view.setUint32(4, count, true);

  // Offset index
  for (let i = 0; i < count; i++) {
    view.setUint32(8 + i * 4, offsets[i], true);
  }

  // Entry table
  let pos = 8 + count * 4;
  for (const buf of entryBuffers) {
    output.set(buf, pos);
    pos += buf.length;
  }

  writeFileSync(outPath, output);

  console.log(`Compiled ${count} entries -> ${outPath}`);
  console.log(`Total size: ${(totalSize / 1024 / 1024).toFixed(1)} MB`);
}

function main() {
  const args = process.argv.slice(2);
  if (args.length < 2) {
    console.log(`Usage: bun scripts/compile-decomp.ts <dictionary.txt> <output.bin>`);
    process.exit(1);
  }

  const entries = parseDictionary(args[0]);
  console.log(`Parsed ${entries.length} entries`);
  compileBinary(entries, args[1]);
}

main();
