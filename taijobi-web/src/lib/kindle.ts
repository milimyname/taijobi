/**
 * Kindle `My Clippings.txt` import — UI adapter.
 *
 * Parsing itself lives in `libtaijobi/src/kindle.zig` and is exposed via the
 * `hanzi_parse_kindle` WASM export; this module just wraps the call so the
 * Svelte page gets a typed array back. When iOS ships, the Zig parser runs
 * unchanged there too.
 */
import { parseKindleClippings } from './wasm';

export type ClippingType = 'highlight' | 'note' | 'bookmark';

export interface KindleEntry {
	book: string;
	author: string;
	type: ClippingType;
	text: string;
}

/** Parse the full contents of a My Clippings.txt file via the WASM export. */
export function parseClippings(raw: string): KindleEntry[] {
	return parseKindleClippings(raw);
}

/** Word count heuristic for the "short clipping" filter — short clippings
 *  are usually dictionary lookups (single words), long ones are passages.
 *  Stays in TS because it's pure UI filtering — no reason to round-trip. */
export function wordCount(text: string): number {
	// Count CJK chars as 1 "word" each for the purposes of the short-filter.
	// Otherwise split on whitespace.
	let cjkCount = 0;
	let nonCjk = '';
	for (const ch of text) {
		const cp = ch.codePointAt(0) ?? 0;
		if (
			(cp >= 0x4e00 && cp <= 0x9fff) ||
			(cp >= 0x3400 && cp <= 0x4dbf) ||
			(cp >= 0x20000 && cp <= 0x2a6df)
		) {
			cjkCount++;
		} else {
			nonCjk += ch;
		}
	}
	const nonCjkWords = nonCjk.trim().split(/\s+/).filter(Boolean).length;
	return cjkCount + nonCjkWords;
}
