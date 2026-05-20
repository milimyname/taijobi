/**
 * Detects dictionaries that need re-downloading for one of two reasons:
 *
 *   1. **Stale format** — the OPFS .bin exists but the magic header doesn't
 *      validate against the current WASM (e.g. WKE2 → WKE3 format bump).
 *      Caught by `detectStaleDictionaries`.
 *   2. **Missing after interrupted update** — LS_INSTALLED_DICTS says the
 *      user intended this dict to be installed, but it isn't currently
 *      loaded into WASM. Happens when iOS kills the PWA mid-update fetch
 *      after the old OPFS bytes were already deleted. Caught by
 *      `detectMissingDictionaries`.
 *
 * Both cases resolve via the same flow (drop any leftover OPFS bytes, reset
 * the persist arena, redownload). The banner just opens a Drawer so the
 * user gets size info + a Wi-Fi nudge before committing to the bandwidth.
 *
 * Dismissal is NOT persisted: stale or missing dicts silently break lookup,
 * so a reload should re-prompt. Once the user actually refreshes,
 * `affectedKinds` empties and the banner stays hidden until something
 * regresses again.
 */

import {
	detectMissingDictionaries,
	detectStaleDictionaries,
	refreshStaleDictionaries
} from './dictionary-data';
import type { DictKind } from './installed-dicts';

class DictUpdateStore {
	affectedKinds = $state<DictKind[]>([]);
	dismissed = $state(false);
	sheetOpen = $state(false);
	busy = $state(false);
	error = $state<string | null>(null);

	async check(): Promise<void> {
		try {
			const stale = await detectStaleDictionaries();
			const missing = detectMissingDictionaries();
			// Union — a kind could plausibly land in both lists. Order kept stable
			// (zh, en, de) so banner copy is deterministic across re-checks.
			const ordered: DictKind[] = ['zh', 'en', 'de'];
			const set = new Set<DictKind>([...stale, ...missing]);
			this.affectedKinds = ordered.filter((k) => set.has(k));
		} catch (e) {
			console.warn('[taijobi] dict-update check failed:', e);
		}
	}

	open(): void {
		if (this.affectedKinds.length === 0) return;
		this.sheetOpen = true;
	}

	close(): void {
		// Don't allow closing mid-download — the beforeunload guard in
		// download-state prevents nav anyway, but closing the drawer would
		// hide the progress bar from the user.
		if (this.busy) return;
		this.sheetOpen = false;
	}

	async refresh(): Promise<void> {
		if (this.busy || this.affectedKinds.length === 0) return;
		this.busy = true;
		this.error = null;
		const kinds = [...this.affectedKinds];
		try {
			await refreshStaleDictionaries(kinds);
			await this.check();
			if (this.affectedKinds.length === 0) {
				this.dismissed = false;
				this.sheetOpen = false;
			}
		} catch (e) {
			this.error = e instanceof Error ? e.message : String(e);
			console.error('[taijobi] dict-update refresh failed:', e);
		} finally {
			this.busy = false;
		}
	}

	dismiss(): void {
		this.dismissed = true;
		this.sheetOpen = false;
	}
}

export const dictUpdateStore = new DictUpdateStore();
