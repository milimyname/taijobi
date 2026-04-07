/**
 * First-run onboarding flow. Shows a 4-slide intro on first visit.
 * Dismissal is persisted in localStorage so returning users don't see it again.
 */

import { LS_ONBOARDED } from './config';

class OnboardingStore {
	showOnboarding = $state(false);
	step = $state(0);
	readonly totalSteps = 5;

	init() {
		if (typeof localStorage === 'undefined') return;
		if (localStorage.getItem(LS_ONBOARDED) === '1') return;
		this.showOnboarding = true;
		this.step = 0;
	}

	next() {
		if (this.step < this.totalSteps - 1) {
			this.step++;
		} else {
			this.dismiss();
		}
	}

	dismiss() {
		this.showOnboarding = false;
		this.step = 0;
		try {
			localStorage.setItem(LS_ONBOARDED, '1');
		} catch {
			// Ignore quota errors
		}
	}

	/** Manually re-trigger onboarding (e.g. from Settings → "Show tour again"). */
	reset() {
		try {
			localStorage.removeItem(LS_ONBOARDED);
		} catch {
			// Ignore
		}
		this.step = 0;
		this.showOnboarding = true;
	}
}

export const onboardingStore = new OnboardingStore();
