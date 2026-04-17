/**
 * Streak-in-danger banner logic.
 *
 * Shows on /home when the user has an active streak AND hasn't reviewed
 * anything today. Clicking the banner jumps to /drill; clicking close
 * hides it for the rest of the tab's lifetime (sessionStorage-backed so
 * it doesn't come back on every navigation, but does come back tomorrow).
 *
 * Keeps the logic out of the Svelte template so the rules can change (e.g.
 * add "and review queue is non-empty") without touching the component.
 */
import { data } from './data.svelte';

const SS_KEY = 'taijobi_streak_banner_dismissed';

function todayKey(): string {
	const d = new Date();
	return `${d.getFullYear()}-${d.getMonth()}-${d.getDate()}`;
}

function isDismissedToday(): boolean {
	try {
		return sessionStorage.getItem(SS_KEY) === todayKey();
	} catch {
		return false;
	}
}

class StreakBannerStore {
	#dismissed = $state(false);

	init(): void {
		this.#dismissed = isDismissedToday();
	}

	dismiss(): void {
		this.#dismissed = true;
		try {
			sessionStorage.setItem(SS_KEY, todayKey());
		} catch {
			// Private mode / quota — fall back to in-memory only.
		}
	}

	get dismissed(): boolean {
		return this.#dismissed;
	}
}

export const streakBannerStore = new StreakBannerStore();

export interface StreakBannerState {
	streak: number;
	dueCount: number;
	unreadCount: number;
}

/**
 * Return banner data if the streak is in danger, otherwise null.
 * "In danger" = active streak (≥ 1 day) AND no review recorded today.
 * dueCount / unreadCount come along so the banner can show what's waiting.
 */
export function getBannerState(): StreakBannerState | null {
	const stats = data.stats();
	const drill = data.drillStats();
	if (stats.streak < 1) return null;
	if (drill.reviewed_today > 0) return null;

	const dueCount = data.dueCount();
	const unreadCount = data.unreadCount('');
	if (dueCount === 0 && unreadCount === 0) return null;

	return {
		streak: stats.streak,
		dueCount,
		unreadCount
	};
}
