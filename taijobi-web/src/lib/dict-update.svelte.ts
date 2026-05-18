/**
 * Detects dictionaries whose on-disk format is older than what the WASM can
 * read, and drives the banner that prompts the user to re-download. Triggered
 * by the v3 wiktdict format bump (WKE2→WKE3) where `isEndictLoaded` /
 * `isDedictLoaded` now reject stale bytes by magic — without this banner,
 * the user just sees "Wörterbuch nicht installiert" with no explanation.
 *
 * Dismissal is NOT persisted: stale dicts silently break lookup, so a reload
 * should re-prompt. Once the user actually refreshes, `staleKinds` empties
 * and the banner stays hidden until the next format bump (if ever).
 */

import { detectStaleDictionaries, refreshStaleDictionaries } from './dictionary-data';

type Kind = 'en' | 'de';

class DictUpdateStore {
	staleKinds = $state<Kind[]>([]);
	dismissed = $state(false);
	busy = $state(false);

	async check(): Promise<void> {
		try {
			this.staleKinds = await detectStaleDictionaries();
		} catch (e) {
			console.warn('[taijobi] dict-update check failed:', e);
		}
	}

	async refresh(): Promise<void> {
		if (this.busy || this.staleKinds.length === 0) return;
		this.busy = true;
		const kinds = [...this.staleKinds];
		try {
			await refreshStaleDictionaries(kinds);
			this.staleKinds = [];
			this.dismissed = false;
		} finally {
			this.busy = false;
		}
	}

	dismiss(): void {
		this.dismissed = true;
	}
}

export const dictUpdateStore = new DictUpdateStore();
