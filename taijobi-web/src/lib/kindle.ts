/**
 * Kindle `My Clippings.txt` parser.
 *
 * Format: entries separated by `==========` on its own line. Each entry is:
 *
 *   Title (Author)
 *   - Your Highlight on page X | Location Y-Z | Added on <date>
 *
 *   <the highlighted text, possibly multi-line>
 *
 * Metadata lines are localized (German: "Ihre Markierung auf Seite X | Position
 * Y-Z | Hinzugefügt am ..."), but the overall structure holds for every locale.
 */

export type ClippingType = 'highlight' | 'note' | 'bookmark';

export interface KindleEntry {
	book: string;
	author: string;
	type: ClippingType;
	text: string;
}

function stripBom(s: string): string {
	return s.charCodeAt(0) === 0xfeff ? s.slice(1) : s;
}

function detectType(metaLine: string): ClippingType {
	if (/\b(note|notiz)\b/i.test(metaLine)) return 'note';
	if (/\b(bookmark|lesezeichen|marque-page)\b/i.test(metaLine)) return 'bookmark';
	return 'highlight';
}

function parseTitleAndAuthor(line: string): { book: string; author: string } {
	// Match the LAST parenthesized group, so titles with parens in them
	// don't steal the author: "Title (foo) (Author)" → author="Author".
	const m = line.trim().match(/^(.*?)\s*\(([^)]+)\)\s*$/);
	if (!m) return { book: line.trim(), author: '' };
	return { book: m[1].trim(), author: m[2].trim() };
}

/** Parse the full contents of a My Clippings.txt file. */
export function parseClippings(raw: string): KindleEntry[] {
	const text = stripBom(raw).replace(/\r\n/g, '\n').replace(/\r/g, '\n');
	const blocks = text.split(/^==========$/m);
	const entries: KindleEntry[] = [];

	for (const block of blocks) {
		const trimmed = block.trim();
		if (!trimmed) continue;
		const lines = trimmed.split('\n');
		if (lines.length < 3) continue;

		const { book, author } = parseTitleAndAuthor(lines[0]);
		const type = detectType(lines[1]);
		const bodyText = lines.slice(2).join('\n').trim();
		if (!bodyText) continue;
		// Skip bookmarks — they have no text to import.
		if (type === 'bookmark') continue;

		entries.push({ book, author, type, text: bodyText });
	}

	return entries;
}

/** Word count heuristic for the "short clipping" filter — short clippings
 *  are usually dictionary lookups (single words), long ones are passages. */
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
