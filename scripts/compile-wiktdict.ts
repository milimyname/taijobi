/**
 * Compile Wiktextract JSONL data into a compact binary dictionary.
 *
 * Usage:
 *   bun scripts/compile-wiktdict.ts <input.jsonl> <output.bin> <magic>
 *
 * Example:
 *   bun scripts/compile-wiktdict.ts data/kaikki-en.jsonl taijobi-web/static/data/endict.bin WKE3
 *   bun scripts/compile-wiktdict.ts data/kaikki-de.jsonl taijobi-web/static/data/dedict.bin WKD3
 *
 * Binary format (v3):
 *   Header (8 bytes): magic (4 bytes, "WKE3" or "WKD3") + count: u32 LE
 *   Index  (count × 4 bytes): offset[i]: u32 LE — byte offset into entry table
 *
 *   Entry table — each entry, sorted by lowercase word (UTF-8 byte order):
 *     u8  word_len
 *     bytes word
 *     u8  pos_count
 *     for each POS group:
 *       u8  pos_len, bytes pos                  (short label: "n", "v", "adj", …)
 *       u16 LE etymology_len, bytes etymology   (0 = none)
 *       u8  sense_count
 *       for each sense (in original order):
 *         u8  tag_count
 *         for each tag: u8 tag_len, bytes tag   (e.g. "informal", "transitive")
 *         u16 LE gloss_len, bytes gloss
 *         u16 LE example_len, bytes example     (0 = no example)
 *         u8  syn_count;  for each: u8 len, bytes
 *         u8  ant_count;  for each: u8 len, bytes
 *         u8  hyp_count;  for each: u8 len, bytes
 *
 * v2 (WKE2/WKD2) entries had no etymology/synonyms/antonyms/hypernyms — the
 * magic bump forces a re-download so stale OPFS caches don't silently render
 * with missing fields.
 */

import { createReadStream, writeFileSync } from "fs";
import { createInterface } from "readline";

const encoder = new TextEncoder();

const MAX_GLOSS_LEN = 400;
const MAX_EXAMPLE_LEN = 240;
const MAX_ETYMOLOGY_LEN = 280;
const MAX_SENSES_PER_POS = 6;
const MAX_TAGS_PER_SENSE = 4;
const MAX_POS_PER_WORD = 6;
const MAX_SYNONYMS_PER_SENSE = 6;
const MAX_ANTONYMS_PER_SENSE = 4;
const MAX_HYPERNYMS_PER_SENSE = 4;
const MAX_RELATION_LEN = 60; // any single synonym/antonym/hypernym word

// Short POS labels — kept stable across format versions so the UI can group on them.
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

// Wiktextract puts many tags on each sense, most are not display-worthy.
// Allowlist: register, domain, usage, common grammar hints, region.
const TAG_ALLOW = new Set([
	// register / usage
	"informal", "formal", "colloquial", "slang", "vulgar", "literary",
	"archaic", "obsolete", "dated", "rare", "humorous", "derogatory",
	"euphemistic", "poetic", "neologism", "nonstandard", "proscribed",
	// domain hints (small list — Wiktextract has hundreds, only the most
	// commonly meaningful ones for everyday lookup)
	"technical", "medical", "medicine", "law", "legal", "computing",
	"music", "physics", "chemistry", "biology", "mathematics", "math",
	"linguistics", "anatomy", "botany", "cooking", "military",
	// grammar (verbs)
	"transitive", "intransitive", "reflexive", "auxiliary",
	// region
	"British", "American", "Australian", "Canadian", "Irish", "Scottish",
	"India", "South-African", "New-Zealand",
]);

interface WiktExample {
	text?: string;
	ref?: string;
}

interface WiktRelation {
	word?: string;
	sense?: string;
	tags?: string[];
}

interface WiktSense {
	glosses?: string[];
	raw_glosses?: string[];
	tags?: string[];
	examples?: WiktExample[];
	synonyms?: WiktRelation[];
	antonyms?: WiktRelation[];
	hypernyms?: WiktRelation[];
	form_of?: Array<{ word: string }>;
}

interface WiktRawEntry {
	word: string;
	pos: string;
	senses?: WiktSense[];
	etymology_text?: string;
	synonyms?: WiktRelation[];
	antonyms?: WiktRelation[];
	hypernyms?: WiktRelation[];
}

interface CompiledSense {
	tags: string[];
	gloss: string;
	example: string;
	synonyms: string[];
	antonyms: string[];
	hypernyms: string[];
}

interface CompiledPos {
	pos: string;
	etymology: string;
	senses: CompiledSense[];
}

interface CompiledEntry {
	word: string;
	posGroups: CompiledPos[];
}

function cleanGloss(s: string): string {
	return s.trim();
}

function cleanEtymology(s: string | undefined): string {
	if (!s) return "";
	// Wiktextract etymologies often start with "From " / "Inherited from " and
	// can be paragraphs. Take the first sentence to keep cards readable.
	const trimmed = s.trim().replace(/\s+/g, " ");
	if (!trimmed) return "";
	// First sentence terminator — prefer a real one but cap at MAX_ETYMOLOGY_LEN.
	const firstDot = trimmed.search(/[.!?](\s|$)/);
	const sentence = firstDot > 40 ? trimmed.slice(0, firstDot + 1) : trimmed;
	if (sentence.length > MAX_ETYMOLOGY_LEN) {
		return sentence.slice(0, MAX_ETYMOLOGY_LEN - 1) + "…";
	}
	return sentence;
}

function pickExample(sense: WiktSense): string {
	const ex = sense.examples ?? [];
	for (const e of ex) {
		const t = e.text?.trim();
		if (!t) continue;
		if (t.length > MAX_EXAMPLE_LEN) continue;
		return t;
	}
	const first = ex[0]?.text?.trim();
	if (first) {
		return first.length > MAX_EXAMPLE_LEN
			? first.slice(0, MAX_EXAMPLE_LEN - 1) + "…"
			: first;
	}
	return "";
}

function filterTags(raw: string[] | undefined): string[] {
	if (!raw?.length) return [];
	const out: string[] = [];
	const seen = new Set<string>();
	for (const t of raw) {
		if (!TAG_ALLOW.has(t)) continue;
		if (seen.has(t)) continue;
		seen.add(t);
		out.push(t);
		if (out.length >= MAX_TAGS_PER_SENSE) break;
	}
	return out;
}

/**
 * Collect related words (synonyms/antonyms/hypernyms) from a relation array.
 * Wiktextract sometimes lists the same word multiple times with different
 * sense-tags or qualifiers — dedupe by lowercase. We strip relations whose
 * word matches the headword itself (self-reference noise).
 */
function collectRelations(
	rels: WiktRelation[] | undefined,
	headword: string,
	cap: number,
): string[] {
	if (!rels?.length) return [];
	const headLower = headword.toLowerCase();
	const out: string[] = [];
	const seen = new Set<string>();
	for (const r of rels) {
		const w = r.word?.trim();
		if (!w) continue;
		if (w.length > MAX_RELATION_LEN) continue;
		const lower = w.toLowerCase();
		if (lower === headLower) continue;
		if (seen.has(lower)) continue;
		seen.add(lower);
		out.push(w);
		if (out.length >= cap) break;
	}
	return out;
}

function compileSenses(senses: WiktSense[], headword: string): CompiledSense[] {
	const out: CompiledSense[] = [];
	for (const s of senses) {
		if (out.length >= MAX_SENSES_PER_POS) break;
		if (!s.glosses?.length) continue;
		if (s.form_of?.length) continue;
		if (s.tags?.includes("form-of")) continue;

		let g = cleanGloss(s.glosses[s.glosses.length - 1] ?? "");
		if (!g) continue;
		if (g.length > MAX_GLOSS_LEN) {
			g = g.slice(0, MAX_GLOSS_LEN - 1) + "…";
		}

		out.push({
			tags: filterTags(s.tags),
			gloss: g,
			example: pickExample(s),
			synonyms: collectRelations(s.synonyms, headword, MAX_SYNONYMS_PER_SENSE),
			antonyms: collectRelations(s.antonyms, headword, MAX_ANTONYMS_PER_SENSE),
			hypernyms: collectRelations(s.hypernyms, headword, MAX_HYPERNYMS_PER_SENSE),
		});
	}
	return out;
}

async function parseJsonlStream(inputPath: string): Promise<CompiledEntry[]> {
	const byWord = new Map<string, Map<string, CompiledPos>>();
	let total = 0;
	let skipped = 0;

	const rl = createInterface({
		input: createReadStream(inputPath, { encoding: "utf-8" }),
		crlfDelay: Infinity,
	});

	for await (const line of rl) {
		if (!line.trim()) continue;
		total++;

		if (total % 100000 === 0) {
			process.stdout.write(`  ${total} lines processed, ${byWord.size} unique words…\r`);
		}

		let raw: WiktRawEntry;
		try {
			raw = JSON.parse(line);
		} catch {
			skipped++;
			continue;
		}

		const word = raw.word?.trim();
		if (!word || word.length > 255) continue;

		const senses = compileSenses(raw.senses ?? [], word);
		if (senses.length === 0) {
			skipped++;
			continue;
		}

		// Entry-level synonyms/antonyms/hypernyms apply broadly — fold them into
		// the FIRST sense so they're surfaced somewhere. (Putting them on every
		// sense would inflate the binary; users see the most-relevant sense first
		// anyway.) Dedupe against what's already there.
		const headSyn = collectRelations(raw.synonyms, word, MAX_SYNONYMS_PER_SENSE);
		const headAnt = collectRelations(raw.antonyms, word, MAX_ANTONYMS_PER_SENSE);
		const headHyp = collectRelations(raw.hypernyms, word, MAX_HYPERNYMS_PER_SENSE);
		if (senses[0]) {
			senses[0].synonyms = mergeCapped(senses[0].synonyms, headSyn, MAX_SYNONYMS_PER_SENSE);
			senses[0].antonyms = mergeCapped(senses[0].antonyms, headAnt, MAX_ANTONYMS_PER_SENSE);
			senses[0].hypernyms = mergeCapped(senses[0].hypernyms, headHyp, MAX_HYPERNYMS_PER_SENSE);
		}

		const pos = POS_MAP[raw.pos] ?? raw.pos?.slice(0, 4) ?? "";
		const etymology = cleanEtymology(raw.etymology_text);

		const key = word.toLowerCase();
		let posMap = byWord.get(key);
		if (!posMap) {
			posMap = new Map();
			byWord.set(key, posMap);
		}

		const existing = posMap.get(pos);
		if (existing) {
			for (const s of senses) {
				if (existing.senses.length >= MAX_SENSES_PER_POS) break;
				existing.senses.push(s);
			}
			// Keep the first non-empty etymology we saw for this (word, pos).
			if (!existing.etymology && etymology) existing.etymology = etymology;
		} else {
			if (posMap.size >= MAX_POS_PER_WORD) continue;
			posMap.set(pos, { pos, etymology, senses });
		}
	}

	console.log(`\n  ${total} lines total, skipped ${skipped}, ${byWord.size} unique words`);

	const entries: CompiledEntry[] = [];
	for (const [key, posMap] of byWord) {
		entries.push({
			word: key,
			posGroups: [...posMap.values()],
		});
	}
	return entries;
}

function mergeCapped(a: string[], b: string[], cap: number): string[] {
	if (b.length === 0) return a;
	const seen = new Set(a.map((s) => s.toLowerCase()));
	const out = [...a];
	for (const x of b) {
		const lo = x.toLowerCase();
		if (seen.has(lo)) continue;
		seen.add(lo);
		out.push(x);
		if (out.length >= cap) break;
	}
	return out;
}

function compareBytes(a: Uint8Array, b: Uint8Array): number {
	const len = Math.min(a.length, b.length);
	for (let i = 0; i < len; i++) {
		if (a[i] !== b[i]) return a[i] - b[i];
	}
	return a.length - b.length;
}

function encodeEntry(entry: CompiledEntry): Uint8Array {
	const chunks: Uint8Array[] = [];
	let size = 0;

	const pushU8 = (v: number) => {
		const b = new Uint8Array(1);
		b[0] = v;
		chunks.push(b);
		size += 1;
	};
	const pushU16LE = (v: number) => {
		const b = new Uint8Array(2);
		b[0] = v & 0xff;
		b[1] = (v >> 8) & 0xff;
		chunks.push(b);
		size += 2;
	};
	const pushBytes = (b: Uint8Array) => {
		chunks.push(b);
		size += b.length;
	};
	const pushLenPrefixed8 = (s: string) => {
		const b = encoder.encode(s);
		const len = Math.min(b.length, 255);
		pushU8(len);
		pushBytes(b.subarray(0, len));
	};
	const pushLenPrefixed16 = (s: string) => {
		let b = encoder.encode(s);
		if (b.length > 65535) b = b.slice(0, 65535);
		pushU16LE(b.length);
		pushBytes(b);
	};

	const wBytes = encoder.encode(entry.word);
	if (wBytes.length > 255) throw new Error(`word too long: ${entry.word}`);
	pushU8(wBytes.length);
	pushBytes(wBytes);

	const posGroups = entry.posGroups.slice(0, MAX_POS_PER_WORD);
	pushU8(posGroups.length);

	for (const pg of posGroups) {
		const pBytes = encoder.encode(pg.pos);
		if (pBytes.length > 255) throw new Error(`pos too long: ${pg.pos}`);
		pushU8(pBytes.length);
		pushBytes(pBytes);

		pushLenPrefixed16(pg.etymology);

		const senses = pg.senses.slice(0, MAX_SENSES_PER_POS);
		pushU8(senses.length);

		for (const s of senses) {
			const tags = s.tags.slice(0, MAX_TAGS_PER_SENSE);
			pushU8(tags.length);
			for (const t of tags) pushLenPrefixed8(t);

			pushLenPrefixed16(s.gloss);
			pushLenPrefixed16(s.example);

			const syn = s.synonyms.slice(0, MAX_SYNONYMS_PER_SENSE);
			pushU8(syn.length);
			for (const x of syn) pushLenPrefixed8(x);

			const ant = s.antonyms.slice(0, MAX_ANTONYMS_PER_SENSE);
			pushU8(ant.length);
			for (const x of ant) pushLenPrefixed8(x);

			const hyp = s.hypernyms.slice(0, MAX_HYPERNYMS_PER_SENSE);
			pushU8(hyp.length);
			for (const x of hyp) pushLenPrefixed8(x);
		}
	}

	const out = new Uint8Array(size);
	let off = 0;
	for (const c of chunks) {
		out.set(c, off);
		off += c.length;
	}
	return out;
}

function compileBinary(entries: CompiledEntry[], magic: string): Uint8Array {
	entries.sort((a, b) =>
		compareBytes(encoder.encode(a.word), encoder.encode(b.word)),
	);

	const entryBlobs: Uint8Array[] = [];
	const offsets: number[] = [];
	let cursor = 0;

	for (const entry of entries) {
		const blob = encodeEntry(entry);
		offsets.push(cursor);
		entryBlobs.push(blob);
		cursor += blob.length;
	}

	const count = entries.length;
	const headerSize = 8;
	const indexSize = count * 4;
	const total = headerSize + indexSize + cursor;
	const result = new Uint8Array(total);
	const view = new DataView(result.buffer);

	for (let i = 0; i < 4; i++) result[i] = magic.charCodeAt(i);
	view.setUint32(4, count, true);

	for (let i = 0; i < count; i++) {
		view.setUint32(headerSize + i * 4, offsets[i], true);
	}

	let pos = headerSize + indexSize;
	for (const b of entryBlobs) {
		result.set(b, pos);
		pos += b.length;
	}

	return result;
}

async function main() {
	if (process.argv.length < 5) {
		console.log("Usage: bun scripts/compile-wiktdict.ts <input.jsonl> <output.bin> <magic>");
		console.log("  magic: WKE3 for English, WKD3 for German (v3 format)");
		process.exit(1);
	}

	const inputPath = process.argv[2];
	const outputPath = process.argv[3];
	const magic = process.argv[4];

	if (magic.length !== 4) {
		console.error("Magic must be exactly 4 characters");
		process.exit(1);
	}
	if (magic !== "WKE3" && magic !== "WKD3") {
		console.warn(`Magic ${magic} is non-standard. Expected WKE3 or WKD3 for v3 format.`);
	}

	console.log(`Reading ${inputPath}…`);
	const entries = await parseJsonlStream(inputPath);
	console.log(`Compiled ${entries.length} unique entries`);

	const binary = compileBinary(entries, magic);
	writeFileSync(outputPath, binary);

	const sizeMB = (binary.length / 1024 / 1024).toFixed(1);
	console.log(`Written ${outputPath} (${sizeMB} MB, ${entries.length} entries)`);
}

main();
