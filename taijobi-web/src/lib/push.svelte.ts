/**
 * Web Push subscription management.
 *
 * Handles the full lifecycle: request permission → subscribe via PushManager
 * → send the subscription to the sync Worker → heartbeat on each review.
 * The server publishes its VAPID public key at /push/vapid-public-key and
 * the client follows it: when the key a subscription was made with no longer
 * matches, the client re-subscribes silently (permission is already granted),
 * so the server's key can rotate without an app release.
 */
import { SYNC_API_URL, LS_SYNC_KEY } from './config';

// Fallback VAPID public key (base64url, 65-byte uncompressed P-256 point) for
// servers without /push/vapid-public-key — the Cloudflare Worker, whose private
// key is a wrangler secret.
const FALLBACK_VAPID_PUBLIC_KEY =
	'BK9oASOZIlC4POEOW-VROIDMJlCA7qR88-m7R6GIRg6lGAZlHq6F8cTGXZKDPYb6my4MTFWz3Z6LGPWMCfiRsAQ';

const LS_PUSH_SUBSCRIBED = 'taijobi_push_subscribed';

function urlBase64ToUint8Array(base64String: string): Uint8Array {
	const padding = '='.repeat((4 - (base64String.length % 4)) % 4);
	const base64 = (base64String + padding).replace(/-/g, '+').replace(/_/g, '/');
	const raw = atob(base64);
	const out = new Uint8Array(raw.length);
	for (let i = 0; i < raw.length; i++) out[i] = raw.charCodeAt(i);
	return out;
}

function uint8ArrayToUrlBase64(bytes: Uint8Array): string {
	let s = '';
	for (const b of bytes) s += String.fromCharCode(b);
	return btoa(s).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

/**
 * The server's current VAPID public key; the fallback when the server answers
 * but doesn't publish one (the Worker); null when it can't be reached — then
 * callers must leave existing subscriptions alone rather than guess.
 */
async function fetchVapidKey(): Promise<string | null> {
	let res: Response;
	try {
		res = await fetch(`${SYNC_API_URL}/push/vapid-public-key`);
	} catch {
		return null;
	}
	if (res.ok) {
		try {
			const { key } = (await res.json()) as { key?: string };
			if (key) return key;
		} catch {
			/* malformed — treat like a server without the endpoint */
		}
	}
	return FALLBACK_VAPID_PUBLIC_KEY;
}

function getSyncKey(): string | null {
	try {
		return localStorage.getItem(LS_SYNC_KEY);
	} catch {
		return null;
	}
}

class PushStore {
	permission = $state<NotificationPermission>('default');
	subscribed = $state(false);
	supported = $state(false);

	init(): void {
		if (typeof window === 'undefined') return;
		this.supported =
			'Notification' in window && 'serviceWorker' in navigator && 'PushManager' in window;
		if (this.supported) {
			this.permission = Notification.permission;
		}
		try {
			this.subscribed = localStorage.getItem(LS_PUSH_SUBSCRIBED) === '1';
		} catch {
			this.subscribed = false;
		}
		if (this.subscribed && this.permission === 'granted') void this.resync();
	}

	/**
	 * Re-send the browser's subscription on every start. The server upserts,
	 * so this is a no-op normally — but it rebuilds the server's copy after a
	 * server move (sync.taijobi.com left Cloudflare) or data loss, and swaps the
	 * subscription for a fresh one when the server's VAPID key changed. Without
	 * it, reminders would silently stop until the user toggled push off/on.
	 */
	private async resync(): Promise<void> {
		const syncKey = getSyncKey();
		if (!syncKey) return;
		try {
			const reg = await navigator.serviceWorker.ready;
			let sub = await reg.pushManager.getSubscription();
			const serverKey = await fetchVapidKey();
			if (!serverKey) return; // offline — keep whatever we have
			const subKey = sub?.options.applicationServerKey;
			if (!sub || !subKey || uint8ArrayToUrlBase64(new Uint8Array(subKey)) !== serverKey) {
				// Missing, or tied to an old key the server can't sign for anymore.
				await sub?.unsubscribe();
				sub = await subscribeWith(reg, serverKey);
			}
			await fetch(`${SYNC_API_URL}/push/subscribe`, {
				method: 'POST',
				headers: {
					'Content-Type': 'application/json',
					Authorization: `Bearer ${syncKey}`
				},
				body: JSON.stringify({ subscription: sub.toJSON() })
			});
		} catch {
			/* offline or SW not ready — next start retries */
		}
	}

	async enable(): Promise<void> {
		if (!this.supported) return;

		const perm = await Notification.requestPermission();
		this.permission = perm;
		if (perm !== 'granted') return;

		const reg = await navigator.serviceWorker.ready;
		const key = await fetchVapidKey();
		if (!key) return; // offline — the toggle stays off, user can retry
		const sub = await subscribeWith(reg, key);

		const syncKey = getSyncKey();
		if (!syncKey) {
			console.warn('[push] No sync key — cannot register subscription on server');
			return;
		}

		const res = await fetch(`${SYNC_API_URL}/push/subscribe`, {
			method: 'POST',
			headers: {
				'Content-Type': 'application/json',
				Authorization: `Bearer ${syncKey}`
			},
			body: JSON.stringify({ subscription: sub.toJSON() })
		});

		if (res.ok) {
			this.subscribed = true;
			try {
				localStorage.setItem(LS_PUSH_SUBSCRIBED, '1');
			} catch {
				/* ignore */
			}
		}
	}

	async disable(): Promise<void> {
		try {
			const reg = await navigator.serviceWorker.ready;
			const sub = await reg.pushManager.getSubscription();
			if (sub) await sub.unsubscribe();
		} catch {
			/* ignore */
		}

		const syncKey = getSyncKey();
		if (syncKey) {
			await fetch(`${SYNC_API_URL}/push/subscribe`, {
				method: 'DELETE',
				headers: { Authorization: `Bearer ${syncKey}` }
			}).catch(() => {});
		}

		this.subscribed = false;
		try {
			localStorage.removeItem(LS_PUSH_SUBSCRIBED);
		} catch {
			/* ignore */
		}
	}

	async heartbeat(): Promise<void> {
		if (!this.subscribed) return;
		const syncKey = getSyncKey();
		if (!syncKey) return;

		fetch(`${SYNC_API_URL}/push/heartbeat`, {
			method: 'POST',
			headers: {
				'Content-Type': 'application/json',
				Authorization: `Bearer ${syncKey}`
			},
			body: JSON.stringify({ ts: Date.now() })
		}).catch(() => {});
	}
}

function subscribeWith(reg: ServiceWorkerRegistration, key: string): Promise<PushSubscription> {
	return reg.pushManager.subscribe({
		userVisibleOnly: true,
		applicationServerKey: urlBase64ToUint8Array(key).buffer as ArrayBuffer
	});
}

export const pushStore = new PushStore();
