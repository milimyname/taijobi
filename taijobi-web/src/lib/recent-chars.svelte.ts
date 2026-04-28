/**
 * Recent characters — small ring buffer of the last N Chinese characters
 * the user visited via /character/[char]. Surfaced in the ⌘K empty state.
 *
 * Only single-grapheme entries are kept. Older versions of the app linked
 * whole sentences into /character/* — those get filtered out on `init()`
 * so the ⌘K chip grid stays a clean row of hanzi.
 */
import { LS_RECENT_CHARS } from './config';

const MAX = 10;

function isSingleChar(s: string): boolean {
	return typeof s === 'string' && [...s].length === 1;
}

class RecentCharsStore {
	chars = $state<string[]>([]);

	init(): void {
		if (typeof localStorage === 'undefined') return;
		try {
			const raw = localStorage.getItem(LS_RECENT_CHARS);
			if (!raw) return;
			const parsed = JSON.parse(raw);
			if (!Array.isArray(parsed)) return;

			const cleaned = parsed.filter(isSingleChar).slice(0, MAX);
			this.chars = cleaned;

			// Persist the cleanup so old multi-char sentences don't haunt
			// the user across reloads.
			if (cleaned.length !== parsed.length) {
				localStorage.setItem(LS_RECENT_CHARS, JSON.stringify(cleaned));
			}
		} catch {
			/* ignore */
		}
	}

	visit(ch: string): void {
		if (!isSingleChar(ch)) return;
		const deduped = [ch, ...this.chars.filter((c) => c !== ch)].slice(0, MAX);
		this.chars = deduped;
		try {
			localStorage.setItem(LS_RECENT_CHARS, JSON.stringify(deduped));
		} catch {
			/* quota — ignore */
		}
	}

	clear(): void {
		this.chars = [];
		try {
			localStorage.removeItem(LS_RECENT_CHARS);
		} catch {
			/* ignore */
		}
	}
}

export const recentCharsStore = new RecentCharsStore();
