#!/usr/bin/env bun
/**
 * Generate minimal test .apkg files for Zig tests.
 *
 * Creates two files:
 *   - test_deck_store.apkg   (ZIP with STORE compression)
 *   - test_deck_deflate.apkg (ZIP with DEFLATE compression)
 *
 * Each contains a tiny Anki SQLite database with 2 notes.
 */

import { Database } from "bun:sqlite";
import { writeFileSync, readFileSync, mkdirSync, unlinkSync } from "node:fs";
import { join, dirname } from "node:path";
import { tmpdir } from "node:os";
import { deflateRawSync } from "node:zlib";

const SCRIPT_DIR = dirname(new URL(import.meta.url).pathname);
const OUT_DIR = join(SCRIPT_DIR, "..", "libtaijobi", "src", "test_data");

function createAnkiDb() {
  const tmpPath = join(tmpdir(), `test-anki-${Date.now()}.db`);
  const db = new Database(tmpPath);

  db.run(`
    CREATE TABLE col (
      id INTEGER PRIMARY KEY,
      models TEXT NOT NULL DEFAULT '{}'
    )
  `);
  db.run(`
    CREATE TABLE notes (
      id INTEGER PRIMARY KEY,
      mid INTEGER NOT NULL,
      flds TEXT NOT NULL
    )
  `);

  const models = {
    "1234567890": {
      flds: [{ name: "\u4e2d\u6587" }, { name: "Pinyin" }, { name: "English" }],
    },
  };
  db.run("INSERT INTO col (id, models) VALUES (1, ?)", [
    JSON.stringify(models),
  ]);

  const sep = "\x1f";
  db.run("INSERT INTO notes (id, mid, flds) VALUES (1, 1234567890, ?)", [
    `\u4f60\u597d${sep}n\u01d0 h\u01ceo${sep}hello`,
  ]);
  db.run("INSERT INTO notes (id, mid, flds) VALUES (2, 1234567890, ?)", [
    `\u8c22\u8c22${sep}xi\u00e8 xie${sep}thank you`,
  ]);

  db.close();

  const bytes = readFileSync(tmpPath);
  unlinkSync(tmpPath);
  return bytes;
}

// ── ZIP construction ────────────────────────────────────────────────────────

function crc32(buf) {
  let crc = 0xffffffff;
  const table = crc32Table();
  for (let i = 0; i < buf.length; i++) {
    crc = (crc >>> 8) ^ table[(crc ^ buf[i]) & 0xff];
  }
  return (crc ^ 0xffffffff) >>> 0;
}

let _crc32Table = null;
function crc32Table() {
  if (_crc32Table) return _crc32Table;
  _crc32Table = new Uint32Array(256);
  for (let i = 0; i < 256; i++) {
    let c = i;
    for (let j = 0; j < 8; j++) {
      c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    }
    _crc32Table[i] = c >>> 0;
  }
  return _crc32Table;
}

function writeU16LE(val) {
  const b = Buffer.alloc(2);
  b.writeUInt16LE(val);
  return b;
}

function writeU32LE(val) {
  const b = Buffer.alloc(4);
  b.writeUInt32LE(val);
  return b;
}

function makeZipLocalHeader(filename, data, method = 0) {
  let compressed;
  if (method === 8) {
    compressed = deflateRawSync(data, { level: 6 });
  } else {
    compressed = data;
  }

  const crc = crc32(data);

  const header = Buffer.concat([
    Buffer.from("PK\x03\x04"),       // signature
    writeU16LE(20),                   // version needed
    writeU16LE(0),                    // flags
    writeU16LE(method),               // compression method
    writeU16LE(0),                    // mod time
    writeU16LE(0),                    // mod date
    writeU32LE(crc),                  // crc32
    writeU32LE(compressed.length),    // compressed size
    writeU32LE(data.length),          // uncompressed size
    writeU16LE(filename.length),      // filename length
    writeU16LE(0),                    // extra field length
  ]);

  return { entry: Buffer.concat([header, filename, compressed]), compressed };
}

function makeZipCentralDir(filename, data, compressed, localOffset, method = 0) {
  const crc = crc32(data);

  const entry = Buffer.concat([
    Buffer.from("PK\x01\x02"),       // signature
    writeU16LE(20),                   // version made by
    writeU16LE(20),                   // version needed
    writeU16LE(0),                    // flags
    writeU16LE(method),               // compression method
    writeU16LE(0),                    // mod time
    writeU16LE(0),                    // mod date
    writeU32LE(crc),                  // crc32
    writeU32LE(compressed.length),    // compressed size
    writeU32LE(data.length),          // uncompressed size
    writeU16LE(filename.length),      // filename length
    writeU16LE(0),                    // extra length
    writeU16LE(0),                    // comment length
    writeU16LE(0),                    // disk number start
    writeU16LE(0),                    // internal attributes
    writeU32LE(0),                    // external attributes
    writeU32LE(localOffset),          // local header offset
  ]);

  return Buffer.concat([entry, filename]);
}

function makeZipEocd(cdOffset, cdSize, numEntries) {
  return Buffer.concat([
    Buffer.from("PK\x05\x06"),
    writeU16LE(0),                    // disk number
    writeU16LE(0),                    // disk with CD
    writeU16LE(numEntries),
    writeU16LE(numEntries),
    writeU32LE(cdSize),
    writeU32LE(cdOffset),
    writeU16LE(0),                    // comment length
  ]);
}

function makeApkg(dbBytes, method = 0) {
  const filename = Buffer.from("collection.anki2");

  const { entry: local, compressed } = makeZipLocalHeader(
    filename,
    dbBytes,
    method,
  );
  const cdOffset = local.length;
  const cd = makeZipCentralDir(filename, dbBytes, compressed, 0, method);
  const eocd = makeZipEocd(cdOffset, cd.length, 1);

  return Buffer.concat([local, cd, eocd]);
}

// ── Main ────────────────────────────────────────────────────────────────────

function main() {
  mkdirSync(OUT_DIR, { recursive: true });
  const dbBytes = createAnkiDb();

  const storePath = join(OUT_DIR, "test_deck_store.apkg");
  const storeData = makeApkg(dbBytes, 0);
  writeFileSync(storePath, storeData);
  console.log(`  wrote ${storePath} (${storeData.length} bytes)`);

  const deflatePath = join(OUT_DIR, "test_deck_deflate.apkg");
  const deflateData = makeApkg(dbBytes, 8);
  writeFileSync(deflatePath, deflateData);
  console.log(`  wrote ${deflatePath} (${deflateData.length} bytes)`);
}

main();
