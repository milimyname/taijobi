/**
 * Feature flag store — persists toggles to localStorage so flags survive
 * reloads. Intended for dark-launching features ahead of a release.
 *
 * Keys come from `DEFAULT_FEATURES` in config.ts (add entries there first).
 * The DevTools Flags tab renders a toggle per key and calls `toggle()`.
 *
 * Ported from wimg's features.svelte.ts — same shape, different LS key.
 */
import { LS_FEATURES, DEFAULT_FEATURES } from './config';

function loadFeatures(): Record<string, boolean> {
	try {
		const stored = localStorage.getItem(LS_FEATURES);
		if (stored) return { ...DEFAULT_FEATURES, ...JSON.parse(stored) };
	} catch {
		// Corrupted JSON — fall through to defaults
	}
	return { ...DEFAULT_FEATURES };
}

function saveFeatures(features: Record<string, boolean>): void {
	localStorage.setItem(LS_FEATURES, JSON.stringify(features));
}

class FeatureStore {
	#features = $state(loadFeatures());

	get enabled(): Record<string, boolean> {
		return this.#features;
	}

	isEnabled(key: string): boolean {
		return this.#features[key] ?? false;
	}

	toggle(key: string): void {
		this.#features = { ...this.#features, [key]: !this.#features[key] };
		saveFeatures(this.#features);
	}

	set(key: string, value: boolean): void {
		this.#features = { ...this.#features, [key]: value };
		saveFeatures(this.#features);
	}
}

export const featureStore = new FeatureStore();
