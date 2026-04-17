/**
 * Web Push subscription management.
 *
 * Handles the full lifecycle: request permission → subscribe via PushManager
 * → send the subscription to the sync Worker → heartbeat on each review.
 * The private VAPID key lives as a Cloudflare Worker secret; only the public
 * key is in this file (safe to commit).
 */
import { SYNC_API_URL, LS_SYNC_KEY } from './config';

// VAPID public key — base64url-encoded, 65-byte uncompressed EC P-256 point.
// The matching private key is stored as a wrangler secret in taijobi-sync.
const VAPID_PUBLIC_KEY =
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
	}

	async enable(): Promise<void> {
		if (!this.supported) return;

		const perm = await Notification.requestPermission();
		this.permission = perm;
		if (perm !== 'granted') return;

		const reg = await navigator.serviceWorker.ready;
		const keyBytes = urlBase64ToUint8Array(VAPID_PUBLIC_KEY);
		const sub = await reg.pushManager.subscribe({
			userVisibleOnly: true,
			applicationServerKey: keyBytes.buffer as ArrayBuffer
		});

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

export const pushStore = new PushStore();
