/**
 * Recent characters — small ring buffer of the last N Chinese characters
 * the user visited via /character/[char]. Surfaced in the ⌘K empty state.
 */
import { LS_RECENT_CHARS } from './config';

const MAX = 10;

class RecentCharsStore {
	chars = $state<string[]>([]);

	init(): void {
		if (typeof localStorage === 'undefined') return;
		try {
			const raw = localStorage.getItem(LS_RECENT_CHARS);
			if (!raw) return;
			const parsed = JSON.parse(raw);
			if (Array.isArray(parsed)) {
				this.chars = parsed.filter((x): x is string => typeof x === 'string').slice(0, MAX);
			}
		} catch {
			/* ignore */
		}
	}

	visit(ch: string): void {
		if (!ch) return;
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
