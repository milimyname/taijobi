import { GITHUB_RELEASES_API, LS_CHANGELOG } from './config';

interface Release {
	tag: string;
	title: string;
	body: string;
	date: string;
}

interface CacheEntry {
	releases: Release[];
	fetchedAt: number;
}

const CACHE_TTL = 60 * 60 * 1000; // 1 hour

function loadCache(): CacheEntry | null {
	try {
		const stored = localStorage.getItem(LS_CHANGELOG);
		if (stored) return JSON.parse(stored) as CacheEntry;
	} catch {
		// ignore
	}
	return null;
}

function saveCache(releases: Release[]) {
	localStorage.setItem(LS_CHANGELOG, JSON.stringify({ releases, fetchedAt: Date.now() }));
}

class ChangelogStore {
	#releases = $state<Release[]>([]);
	#loading = $state(false);
	#error = $state(false);

	get releases() {
		return this.#releases;
	}

	get loading() {
		return this.#loading;
	}

	get error() {
		return this.#error;
	}

	releasesSince(version: string): Release[] {
		const tag = version.startsWith('v') ? version : `v${version}`;
		const idx = this.#releases.findIndex((r) => r.tag === tag);
		if (idx === -1) {
			const lastTag = localStorage.getItem('taijobi-last-version');
			if (lastTag) {
				const lastIdx = this.#releases.findIndex(
					(r) => r.tag === `v${lastTag}` || r.tag === lastTag
				);
				if (lastIdx !== -1) return this.#releases.slice(0, lastIdx);
			}
			return this.#releases.slice(0, 3);
		}
		return this.#releases.slice(0, Math.max(idx, 1));
	}

	async load() {
		const cache = loadCache();

		if (cache && Date.now() - cache.fetchedAt < CACHE_TTL) {
			this.#releases = cache.releases;
			return;
		}

		if (cache) this.#releases = cache.releases;

		this.#loading = true;
		this.#error = false;

		try {
			const res = await fetch(GITHUB_RELEASES_API);
			if (!res.ok) throw new Error(`HTTP ${res.status}`);

			const data = await res.json();
			const releases: Release[] = data.map(
				(r: { tag_name: string; name: string; body: string; published_at: string }) => ({
					tag: r.tag_name,
					title: r.name || r.tag_name,
					body: r.body || '',
					date: r.published_at
				})
			);

			this.#releases = releases;
			saveCache(releases);
		} catch {
			this.#error = true;
		} finally {
			this.#loading = false;
		}
	}
}

export const changelogStore = new ChangelogStore();
