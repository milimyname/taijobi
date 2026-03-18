#!/usr/bin/env bun
/**
 * Extract vocabulary from an Anki .apkg file to TSV.
 *
 * Usage: bun scripts/apkg-to-tsv.js deck.apkg [output.tsv]
 *
 * .apkg = ZIP containing a SQLite DB (collection.anki2 or collection.anki21).
 * Notes are stored with fields separated by 0x1f (unit separator).
 */

import { Database } from "bun:sqlite";
import {
  existsSync,
  readFileSync,
  writeFileSync,
  mkdtempSync,
  rmSync,
} from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { inflateRawSync } from "node:zlib";

/**
 * Remove HTML tags, [sound:...], and decode common HTML entities.
 */
function stripHtml(s) {
  s = s.replace(/\[sound:[^\]]*\]/g, "");
  s = s.replace(/<[^>]+>/g, "");
  // Decode HTML entities
  s = s
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"')
    .replace(/&#039;/g, "'")
    .replace(/&apos;/g, "'")
    .replace(/&#x27;/g, "'")
    .replace(/&nbsp;/g, " ")
    .replace(/&#(\d+);/g, (_, code) => String.fromCodePoint(Number(code)))
    .replace(/&#x([0-9a-fA-F]+);/g, (_, hex) =>
      String.fromCodePoint(parseInt(hex, 16)),
    );
  return s.trim();
}

// ── Minimal ZIP reader ──────────────────────────────────────────────────────

function readZipEntries(buf) {
  const view = new DataView(buf.buffer, buf.byteOffset, buf.byteLength);
  const entries = [];

  // Find End of Central Directory record (scan backwards)
  let eocdOffset = -1;
  for (let i = buf.length - 22; i >= 0; i--) {
    if (
      buf[i] === 0x50 &&
      buf[i + 1] === 0x4b &&
      buf[i + 2] === 0x05 &&
      buf[i + 3] === 0x06
    ) {
      eocdOffset = i;
      break;
    }
  }
  if (eocdOffset === -1) throw new Error("Not a valid ZIP file");

  const cdOffset = view.getUint32(eocdOffset + 16, true);
  const cdEntries = view.getUint16(eocdOffset + 10, true);

  let pos = cdOffset;
  for (let i = 0; i < cdEntries; i++) {
    // Central directory file header
    const sig = view.getUint32(pos, true);
    if (sig !== 0x02014b50) throw new Error("Bad central directory signature");

    const method = view.getUint16(pos + 10, true);
    const compressedSize = view.getUint32(pos + 20, true);
    const uncompressedSize = view.getUint32(pos + 24, true);
    const nameLen = view.getUint16(pos + 28, true);
    const extraLen = view.getUint16(pos + 30, true);
    const commentLen = view.getUint16(pos + 32, true);
    const localOffset = view.getUint32(pos + 42, true);

    const name = new TextDecoder().decode(buf.subarray(pos + 46, pos + 46 + nameLen));

    // Read data from local file header
    const localView = new DataView(buf.buffer, buf.byteOffset + localOffset, 30);
    const localNameLen = localView.getUint16(26, true);
    const localExtraLen = localView.getUint16(28, true);
    const dataStart = localOffset + 30 + localNameLen + localExtraLen;
    const rawData = buf.subarray(dataStart, dataStart + compressedSize);

    let data;
    if (method === 0) {
      data = rawData;
    } else if (method === 8) {
      data = inflateRawSync(rawData);
    } else {
      throw new Error(`Unsupported compression method: ${method}`);
    }

    entries.push({ name, data });
    pos += 46 + nameLen + extraLen + commentLen;
  }

  return entries;
}

// ── Main ────────────────────────────────────────────────────────────────────

function extract(apkgPath, outputPath) {
  if (!existsSync(apkgPath)) {
    console.error(`Error: ${apkgPath} not found`);
    process.exit(1);
  }

  const zipBuf = readFileSync(apkgPath);
  const entries = readZipEntries(zipBuf);

  // Find the SQLite database
  const dbEntry =
    entries.find((e) => e.name === "collection.anki21") ||
    entries.find((e) => e.name === "collection.anki2");

  if (!dbEntry) {
    console.error("Error: no collection database found in .apkg");
    process.exit(1);
  }

  // Write DB to temp file so bun:sqlite can open it
  const tmpDir = mkdtempSync(join(tmpdir(), "apkg-"));
  const dbPath = join(tmpDir, dbEntry.name);
  writeFileSync(dbPath, dbEntry.data);

  let rows;
  try {
    const db = new Database(dbPath, { readonly: true });
    rows = db.query("SELECT flds FROM notes").all();
    db.close();
  } finally {
    rmSync(tmpDir, { recursive: true, force: true });
  }

  if (!rows || rows.length === 0) {
    console.error("No notes found");
    process.exit(1);
  }

  // Split fields by unit separator (0x1f)
  const parsed = [];
  for (const { flds } of rows) {
    const fields = flds.split("\x1f").map(stripHtml);
    if (fields.length > 0 && fields.some((f) => f.length > 0)) {
      parsed.push(fields);
    }
  }

  // Determine max columns
  const maxCols = Math.max(...parsed.map((r) => r.length));

  // Pad short rows and build TSV
  const lines = parsed.map((row) => {
    while (row.length < maxCols) row.push("");
    return row.join("\t");
  });

  const outPath =
    outputPath || apkgPath.replace(/\.apkg$/i, ".tsv");
  writeFileSync(outPath, lines.join("\n") + "\n", "utf-8");
  console.log(`${parsed.length} notes \u2192 ${outPath}`);
}

// ── CLI ─────────────────────────────────────────────────────────────────────

if (process.argv.length < 3) {
  console.error(`Usage: ${process.argv[1]} <deck.apkg> [output.tsv]`);
  process.exit(1);
}

extract(process.argv[2], process.argv[3] || null);
