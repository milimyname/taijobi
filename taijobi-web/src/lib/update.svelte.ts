import { APP_VERSION, RELEASES_URL, IS_BREAKING } from './version';
import { LS_LAST_VERSION, LS_DISMISSED_VERSION } from './config';
import { updated } from '$app/stores';

function getLastVersion(): string | null {
	return localStorage.getItem(LS_LAST_VERSION);
}

function setLastVersion(version: string) {
	localStorage.setItem(LS_LAST_VERSION, version);
}

function getDismissedVersion(): string | null {
	return localStorage.getItem(LS_DISMISSED_VERSION);
}

function setDismissedVersion(version: string) {
	localStorage.setItem(LS_DISMISSED_VERSION, version);
}

function clearDismissedVersion() {
	localStorage.removeItem(LS_DISMISSED_VERSION);
}

class UpdateStore {
	#showBanner = $state(false);
	#sheetOpen = $state(false);
	#waitingSW: ServiceWorker | null = $state(null);

	get showBanner() {
		return this.#showBanner;
	}

	get hasBreaking() {
		return IS_BREAKING;
	}

	get targetVersion() {
		return APP_VERSION;
	}

	get releasesUrl() {
		return RELEASES_URL;
	}

	get sheetOpen() {
		return this.#sheetOpen;
	}

	set sheetOpen(v: boolean) {
		this.#sheetOpen = v;
	}

	init() {
		if (typeof window === 'undefined' || !('serviceWorker' in navigator)) {
			return;
		}

		// First-ever load: seed LS_LAST_VERSION. Subsequent loads: if the user
		// upgraded since we last saw them, bump it now. Previously this only
		// fired inside `controllerchange` (where APP_VERSION still refers to
		// the OLD bundle that's about to be unloaded), so LS_LAST_VERSION
		// permanently lagged one release behind, inflating the "missed
		// releases" list in the changelog drawer.
		const lastVersion = getLastVersion();
		if (lastVersion !== APP_VERSION) {
			setLastVersion(APP_VERSION);
		}

		// If the user dismissed a prior update prompt but the upgrade has now
		// been applied (APP_VERSION moved on), the dismissal is stale —
		// clear it so the next *real* update isn't accidentally suppressed.
		const dismissed = getDismissedVersion();
		if (dismissed && dismissed !== APP_VERSION) {
			clearDismissedVersion();
		}

		navigator.serviceWorker.ready.then((registration) => {
			registration.update(); // check immediately, don't wait for poll
			if (registration.waiting) {
				this.#trackWaitingSW(registration.waiting);
			}

			registration.addEventListener('updatefound', () => {
				const installing = registration.installing;
				if (!installing) return;

				installing.addEventListener('statechange', () => {
					if (installing.state === 'installed' && navigator.serviceWorker.controller) {
						this.#trackWaitingSW(installing);
					}
				});
			});
		});

		updated.subscribe((isUpdated) => {
			if (isUpdated) {
				this.#maybeShowBanner();
				navigator.serviceWorker.ready.then((reg) => reg.update());
			}
		});

		navigator.serviceWorker.addEventListener('controllerchange', () => {
			// Don't write LS_LAST_VERSION here — APP_VERSION still refers to the
			// OLD bundle that's about to be unloaded. The new bundle's init()
			// above handles the bump, where APP_VERSION is correct.
			clearDismissedVersion();
			const overlay = document.createElement('div');
			overlay.style.cssText =
				'position:fixed;inset:0;z-index:9999;background:#fefdfb;opacity:0;transition:opacity 300ms ease';
			document.body.appendChild(overlay);
			requestAnimationFrame(() => {
				overlay.style.opacity = '1';
				overlay.addEventListener('transitionend', () => window.location.reload());
				setTimeout(() => window.location.reload(), 400);
			});
		});
	}

	#trackWaitingSW(sw: ServiceWorker) {
		this.#waitingSW = sw;
		this.#maybeShowBanner();
	}

	/// Show the banner only if the user hasn't already dismissed it for the
	/// version they're currently running. Without this gate, every reload
	/// re-detects the waiting SW (or a stale `updated=true`) and the banner
	/// re-appears immediately.
	#maybeShowBanner() {
		if (getDismissedVersion() === APP_VERSION) return;
		this.#showBanner = true;
	}

	activateUpdate() {
		if (!this.#waitingSW) {
			window.location.reload();
			return;
		}
		// oxlint-disable-next-line require-post-message-target-origin -- ServiceWorker.postMessage's 2nd arg is `transfer`, not a target origin (that's Window.postMessage).
		this.#waitingSW.postMessage({ type: 'SKIP_WAITING' });
	}

	dismiss() {
		this.#showBanner = false;
		// Persist so the banner doesn't pop right back on the next reload
		// while the user is still on this version. Cleared automatically
		// once they actually upgrade (see init()).
		setDismissedVersion(APP_VERSION);
	}

	async clearData() {
		const root = await navigator.storage.getDirectory();
		await Promise.allSettled(['taijobi.db'].map((n) => root.removeEntry(n)));
	}

	async clearDataAndUpdate() {
		await this.clearData();
		this.activateUpdate();
	}
}

export const updateStore = new UpdateStore();
