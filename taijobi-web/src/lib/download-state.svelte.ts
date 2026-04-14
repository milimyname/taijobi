/**
 * Global dictionary-download state.
 *
 * Lives outside any component so progress + active key survive page navigation.
 * Before this existed, a user could tap "Installieren", switch tabs, and come
 * back to a stale UI that showed "Nicht geladen" even though the download was
 * still running in the background. Now the store is the single source of
 * truth — any page reads `downloadStore.active` + `progress` and sees reality.
 */
import { downloadAndLoad, downloadByKeys } from './dictionary-data';
import { data } from './data.svelte';
import { toastStore } from './toast.svelte';

export type DownloadKey = 'zh' | 'en' | 'de';

class DownloadStore {
	active = $state<DownloadKey | null>(null);
	progress = $state(0);
	total = $state(0);

	async start(which: DownloadKey): Promise<void> {
		if (this.active) return;
		this.active = which;
		this.progress = 0;
		this.total = 0;
		const label = which === 'zh' ? 'Chinesisch' : which === 'en' ? 'Englisch' : 'Deutsch';

		// Prevent accidental tab close / page reload during the download. SvelteKit
		// client-side navigation doesn't trigger this, which is exactly what we
		// want — the store keeps driving progress while the user browses.
		const onBeforeUnload = (e: BeforeUnloadEvent) => e.preventDefault();
		window.addEventListener('beforeunload', onBeforeUnload);

		try {
			const cb = (loaded: number, total: number) => {
				this.progress = loaded;
				this.total = total;
			};
			if (which === 'zh') await downloadAndLoad(cb);
			else await downloadByKeys([which === 'en' ? 'endict' : 'dedict'], cb);
			data.bump();
			toastStore.show(`${label}-Wörterbuch geladen`);
		} catch (e) {
			console.error('[taijobi] download failed:', e);
			toastStore.show(`Download fehlgeschlagen: ${e instanceof Error ? e.message : 'Fehler'}`);
		} finally {
			window.removeEventListener('beforeunload', onBeforeUnload);
			this.active = null;
			this.progress = 0;
			this.total = 0;
		}
	}
}

export const downloadStore = new DownloadStore();
