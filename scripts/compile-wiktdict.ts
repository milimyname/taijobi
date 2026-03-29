/**
 * Compile Wiktextract JSONL data into a compact binary dictionary.
 *
 * Usage:
 *   bun scripts/compile-wiktdict.ts <input.jsonl> <output.bin> <magic>
 *
 * Example:
 *   bun scripts/compile-wiktdict.ts data/kaikki-en.jsonl taijobi-web/static/data/endict.bin WKEN
 *   bun scripts/compile-wiktdict.ts data/kaikki-de.jsonl taijobi-web/static/data/dedict.bin WKDE
 *
 * Binary format:
 *   Header (8 bytes): magic (4 bytes) + count: u32 LE
 *   Index (count × 4 bytes): offset[i]: u32 LE
 *   Entries (sorted by lowercase word, UTF-8):
 *     word_len: u8, pos_len: u8, def_len: u16 LE
 *     word bytes, pos bytes, definition bytes
 */

import { createReadStream, writeFileSync } from "fs";
import { createInterface } from "readline";

const encoder = new TextEncoder();

const MAX_DEF_LEN = 500;

// Short POS labels
const POS_MAP: Record<string, string> = {
	noun: "n",
	verb: "v",
	adj: "adj",
	adv: "adv",
	prep: "prep",
	conj: "conj",
	pron: "pron",
	det: "det",
	intj: "intj",
	num: "num",
	particle: "part",
	prefix: "pfx",
	suffix: "sfx",
	phrase: "phr",
	proverb: "prov",
	name: "name",
	abbrev: "abbr",
};

interface WiktEntry {
	word: string;
	pos: string;
	senses?: Array<{
		glosses?: string[];
		tags?: string[];
		form_of?: Array<{ word: string }>;
	}>;
}

async function parseJsonlStream(inputPath: string): Promise<Array<[string, string, string]>> {
	const entries: Array<[string, string, string]> = [];
	const seen = new Set<string>();
	let skipped = 0;
	let total = 0;

	const rl = createInterface({
		input: createReadStream(inputPath, { encoding: "utf-8" }),
		crlfDelay: Infinity
	});

	for await (const line of rl) {
		if (!line.trim()) continue;
		total++;

		if (total % 100000 === 0) {
			process.stdout.write(`  ${total} lines processed, ${entries.length} kept...\r`);
		}

		let entry: WiktEntry;
		try {
			entry = JSON.parse(line);
		} catch {
			skipped++;
			continue;
		}

		const word = entry.word?.trim();
		if (!word || word.length > 255) continue;

		// Skip form-of entries (redirects like "running" -> "run")
		const senses = entry.senses ?? [];
		const hasRealGloss = senses.some(
			(s) => s.glosses?.length && !s.form_of?.length && !s.tags?.includes("form-of"),
		);
		if (!hasRealGloss) {
			skipped++;
			continue;
		}

		// Deduplicate by lowercase word (keep first entry per word)
		const key = word.toLowerCase();
		if (seen.has(key)) continue;
		seen.add(key);

		// Extract POS
		const pos = POS_MAP[entry.pos] ?? entry.pos?.slice(0, 4) ?? "";

		// Extract first meaningful glosses
		let definition = "";
		for (const sense of senses) {
			if (!sense.glosses?.length) continue;
			if (sense.form_of?.length) continue;
			if (sense.tags?.includes("form-of")) continue;

			// Take the last gloss (often the most specific; first can be a category)
			const gloss = sense.glosses[sense.glosses.length - 1];
			if (gloss) {
				if (definition) definition += "; ";
				definition += gloss;
			}
			// Take up to 3 senses
			if (definition.length > MAX_DEF_LEN) break;
		}

		if (!definition) {
			skipped++;
			continue;
		}

		// Truncate definition
		if (definition.length > MAX_DEF_LEN) {
			definition = definition.slice(0, MAX_DEF_LEN - 1) + "\u2026";
		}

		entries.push([word, pos, definition]);
	}

	console.log(`\n  ${total} lines total, skipped ${skipped}, kept ${entries.length}`);
	return entries;
}

function compareBytes(a: Uint8Array, b: Uint8Array): number {
	const len = Math.min(a.length, b.length);
	for (let i = 0; i < len; i++) {
		if (a[i] !== b[i]) return a[i] - b[i];
	}
	return a.length - b.length;
}

function compileBinary(entries: Array<[string, string, string]>, magic: string): Uint8Array {
	// Sort by lowercase word (UTF-8 byte order) for case-insensitive binary search
	entries.sort((a, b) =>
		compareBytes(encoder.encode(a[0].toLowerCase()), encoder.encode(b[0].toLowerCase())),
	);

	const entryChunks: Uint8Array[] = [];
	const offsets: number[] = [];
	let currentOffset = 0;

	for (const [word, pos, definition] of entries) {
		const wBytes = encoder.encode(word);
		const pBytes = encoder.encode(pos);
		let dBytes = encoder.encode(definition);

		if (wBytes.length > 255 || pBytes.length > 255) continue;
		if (dBytes.length > 65535) {
			dBytes = dBytes.slice(0, 65535);
		}

		offsets.push(currentOffset);

		// Header: u8 word_len, u8 pos_len, u16 LE def_len
		const header = new Uint8Array(4);
		header[0] = wBytes.length;
		header[1] = pBytes.length;
		header[2] = dBytes.length & 0xff;
		header[3] = (dBytes.length >> 8) & 0xff;

		entryChunks.push(header, wBytes, pBytes, dBytes);
		currentOffset += 4 + wBytes.length + pBytes.length + dBytes.length;
	}

	const count = offsets.length;
	const headerSize = 8;
	const indexSize = count * 4;
	const totalSize = headerSize + indexSize + currentOffset;
	const result = new Uint8Array(totalSize);
	const view = new DataView(result.buffer);

	// Magic (4 bytes)
	for (let i = 0; i < 4; i++) {
		result[i] = magic.charCodeAt(i);
	}

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
	if (process.argv.length < 5) {
		console.log("Usage: bun scripts/compile-wiktdict.ts <input.jsonl> <output.bin> <magic>");
		console.log("  magic: WKEN for English, WKDE for German");
		process.exit(1);
	}

	const inputPath = process.argv[2];
	const outputPath = process.argv[3];
	const magic = process.argv[4];

	if (magic.length !== 4) {
		console.error("Magic must be exactly 4 characters");
		process.exit(1);
	}

	console.log(`Reading ${inputPath}...`);
	const entries = await parseJsonlStream(inputPath);
	console.log(`Parsed ${entries.length} unique entries`);

	const binary = compileBinary(entries, magic);
	writeFileSync(outputPath, binary);

	const sizeMB = (binary.length / 1024 / 1024).toFixed(1);
	console.log(`Written ${outputPath} (${sizeMB} MB, ${entries.length} entries)`);
}

main();
