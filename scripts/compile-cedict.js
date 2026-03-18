#!/usr/bin/env bun
/**
 * Compile CC-CEDICT text into a binary format for Zig @embedFile().
 *
 * Binary format:
 *   Header (8 bytes):
 *     magic: "CEDI" (4 bytes)
 *     count: u32 LE (number of entries)
 *
 *   Offset index (count * 4 bytes):
 *     offset[i]: u32 LE — byte offset of entry i in the entry table
 *
 *   Entry table (variable-length entries, sorted by simplified UTF-8):
 *     Each entry:
 *       simplified_len: u8
 *       pinyin_len: u8
 *       english_len: u16 LE
 *       simplified: [simplified_len]u8
 *       pinyin: [pinyin_len]u8
 *       english: [english_len]u8
 *
 * Usage:
 *   bun scripts/compile-cedict.js <cedict.txt> <output.bin>
 */

const encoder = new TextEncoder();

const TONE_MARKS = {
	a: ["\u0101", "\u00e1", "\u01ce", "\u00e0", "a"],
	e: ["\u0113", "\u00e9", "\u011b", "\u00e8", "e"],
	i: ["\u012b", "\u00ed", "\u01d0", "\u00ec", "i"],
	o: ["\u014d", "\u00f3", "\u01d2", "\u00f2", "o"],
	u: ["\u016b", "\u00fa", "\u01d4", "\u00f9", "u"],
	"\u00fc": ["\u01d6", "\u01d8", "\u01da", "\u01dc", "\u00fc"],
};

/**
 * Convert a single pinyin syllable with tone number to diacritic form.
 */
function convertSyllable(syl) {
	syl = syl.replace(/u:/g, "\u00fc").replace(/U:/g, "\u00dc");
	if (!syl || !/\d$/.test(syl)) return syl;

	const tone = parseInt(syl[syl.length - 1], 10);
	syl = syl.slice(0, -1);
	if (tone < 1 || tone > 5) return syl;

	const lower = syl.toLowerCase();

	// Rule 1: 'a' or 'e' gets the mark
	for (const v of ["a", "e"]) {
		const idx = lower.indexOf(v);
		if (idx !== -1) {
			const c = syl[idx];
			const key = c.toLowerCase();
			if (key in TONE_MARKS) {
				let replacement = TONE_MARKS[key][tone - 1];
				if (c === c.toUpperCase() && c !== c.toLowerCase()) {
					replacement = replacement.toUpperCase();
				}
				return syl.slice(0, idx) + replacement + syl.slice(idx + 1);
			}
		}
	}

	// Rule 2: 'ou' -> mark on 'o'
	if (lower.includes("ou")) {
		const idx = lower.indexOf("o");
		const c = syl[idx];
		let replacement = TONE_MARKS["o"][tone - 1];
		if (c === c.toUpperCase() && c !== c.toLowerCase()) {
			replacement = replacement.toUpperCase();
		}
		return syl.slice(0, idx) + replacement + syl.slice(idx + 1);
	}

	// Rule 3: last vowel
	for (let i = syl.length - 1; i >= 0; i--) {
		const c = syl[i];
		let key = c.toLowerCase();
		if (key === "\u00fc") key = "\u00fc";
		if (key in TONE_MARKS) {
			let replacement = TONE_MARKS[key][tone - 1];
			if (c === c.toUpperCase() && c !== c.toLowerCase() && key !== "\u00fc") {
				replacement = replacement.toUpperCase();
			}
			return syl.slice(0, i) + replacement + syl.slice(i + 1);
		}
	}

	return syl;
}

/**
 * Convert numbered pinyin to diacritic pinyin.
 */
function pinyinNumbersToDiacritics(pinyin) {
	return pinyin
		.split(" ")
		.map((s) => convertSyllable(s))
		.join(" ");
}

/**
 * Parse CC-CEDICT into [simplified, pinyin, english] tuples.
 */
function parseCedict(text) {
	const entries = [];
	const lines = text.split("\n");

	for (const rawLine of lines) {
		const line = rawLine.trim();
		if (!line || line.startsWith("#")) continue;

		const bracket = line.indexOf("[");
		if (bracket === -1) continue;
		const bracketEnd = line.indexOf("]", bracket);
		if (bracketEnd === -1) continue;

		const charsPart = line.slice(0, bracket).trim();
		const parts = charsPart.split(/\s+/, 2);
		if (parts.length < 2) continue;
		const simplified = parts[1].trim();

		const pinyinRaw = line.slice(bracket + 1, bracketEnd);
		const pinyin = pinyinNumbersToDiacritics(pinyinRaw);

		const defsPart = line.slice(bracketEnd + 1).trim();
		const defs = defsPart.split("/").filter((d) => d.trim());
		let english = defs.join("; ");

		// Truncate english to fit in u16
		if (encoder.encode(english).length > 65535) {
			english = english.slice(0, 500);
		}

		entries.push([simplified, pinyin, english]);
	}

	return entries;
}

/**
 * Compare two Uint8Arrays in byte order.
 */
function compareBytes(a, b) {
	const len = Math.min(a.length, b.length);
	for (let i = 0; i < len; i++) {
		if (a[i] !== b[i]) return a[i] - b[i];
	}
	return a.length - b.length;
}

/**
 * Compile entries into binary format.
 */
function compileBinary(entries) {
	// Sort by simplified (UTF-8 byte order)
	entries.sort((a, b) => compareBytes(encoder.encode(a[0]), encoder.encode(b[0])));

	// Build entry table and offset index
	const entryChunks = [];
	const offsets = [];
	let currentOffset = 0;

	for (const [simplified, pinyin, english] of entries) {
		const sBytes = encoder.encode(simplified);
		const pBytes = encoder.encode(pinyin);
		let eBytes = encoder.encode(english);

		if (sBytes.length > 255 || pBytes.length > 255) continue;
		if (eBytes.length > 65535) {
			eBytes = eBytes.slice(0, 65535);
		}

		offsets.push(currentOffset);

		// Header: u8 simplified_len, u8 pinyin_len, u16 LE english_len
		const header = new Uint8Array(4);
		header[0] = sBytes.length;
		header[1] = pBytes.length;
		header[2] = eBytes.length & 0xff;
		header[3] = (eBytes.length >> 8) & 0xff;

		entryChunks.push(header, sBytes, pBytes, eBytes);
		currentOffset += 4 + sBytes.length + pBytes.length + eBytes.length;
	}

	const count = offsets.length;

	// Build final binary
	const headerSize = 8;
	const indexSize = count * 4;
	const totalSize = headerSize + indexSize + currentOffset;
	const result = new Uint8Array(totalSize);
	const view = new DataView(result.buffer);

	// Magic
	result[0] = 0x43; // C
	result[1] = 0x45; // E
	result[2] = 0x44; // D
	result[3] = 0x49; // I

	// Count
	view.setUint32(4, count, true);

	// Offset index
	for (let i = 0; i < count; i++) {
		view.setUint32(headerSize + i * 4, offsets[i], true);
	}

	// Entry table
	let pos = headerSize + indexSize;
	for (const chunk of entryChunks) {
		result.set(chunk, pos);
		pos += chunk.length;
	}

	return result;
}

async function main() {
	if (process.argv.length < 4) {
		console.log(`Usage: ${process.argv[1]} <cedict.txt> <output.bin>`);
		process.exit(1);
	}

	const inputPath = process.argv[2];
	const outputPath = process.argv[3];

	const text = await Bun.file(inputPath).text();
	const entries = parseCedict(text);
	console.log(`Parsed ${entries.length} entries`);

	const binary = compileBinary(entries);
	const count = new DataView(binary.buffer).getUint32(4, true);

	await Bun.write(outputPath, binary);
	console.log(`Compiled ${count} entries -> ${outputPath}`);
	console.log(`Total size: ${(binary.length / 1024 / 1024).toFixed(1)} MB`);
}

main();
