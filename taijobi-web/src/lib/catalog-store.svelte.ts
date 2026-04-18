/**
 * Shared catalog store — single source of truth for /packs and Cmd+K.
 *
 * Lifts BUILTIN_DICTIONARIES + normalizeEntry out of /packs/+page.svelte so
 * the palette can show pack / dictionary results without duplicating the
 * fetch logic. Seeded synchronously with the built-in dictionaries so the
 * UI renders something useful even before the fetch resolves.
 */

export type CatalogKind = 'content' | 'dictionary';
export type CatalogTag = 'official' | 'community' | 'personal' | string;

export interface CatalogEntry {
	id: string;
	kind: CatalogKind;
	tag: CatalogTag;
	name: string;
	language_pair: string;
	description: string;
	word_count?: number;
	size_mb?: number;
}

export const BUILTIN_DICTIONARIES: CatalogEntry[] = [
	{
		id: 'dict-zh',
		kind: 'dictionary',
		tag: 'official',
		name: 'Chinesisches Wörterbuch',
		language_pair: 'zh',
		size_mb: 19,
		description: 'CC-CEDICT, Strichfolge und Zeichenzerlegung'
	},
	{
		id: 'dict-en',
		kind: 'dictionary',
		tag: 'official',
		name: 'Englisches Wörterbuch',
		language_pair: 'en',
		size_mb: 19,
		description: 'Wiktionary-Definitionen (Englisch)'
	},
	{
		id: 'dict-de',
		kind: 'dictionary',
		tag: 'official',
		name: 'Deutsches Wörterbuch',
		language_pair: 'de',
		size_mb: 5,
		description: 'Wiktionary-Definitionen (Deutsch)'
	}
];

export function normalizeEntry(
	raw: Partial<CatalogEntry> & { id: string; name: string }
): CatalogEntry {
	return {
		id: raw.id,
		kind: raw.kind ?? 'content',
		tag: raw.tag ?? 'official',
		name: raw.name,
		language_pair: raw.language_pair ?? '',
		description: raw.description ?? '',
		word_count: raw.word_count,
		size_mb: raw.size_mb
	};
}

export function tagLabel(tag: CatalogTag): string {
	if (tag === 'official') return 'Offiziell';
	if (tag === 'community') return 'Community';
	if (tag === 'personal') return 'Persönlich';
	return tag;
}

export function tagBadgeClass(tag: CatalogTag): string {
	if (tag === 'official') return 'bg-primary/10 text-primary dark:bg-primary/20';
	if (tag === 'community')
		return 'bg-amber-100 text-amber-700 dark:bg-amber-500/15 dark:text-amber-300';
	return 'bg-slate-100 text-slate-600 dark:bg-white/10 dark:text-slate-300';
}

class CatalogStore {
	entries = $state<CatalogEntry[]>([...BUILTIN_DICTIONARIES]);
	private loaded = false;
	private loading: Promise<void> | null = null;

	/** Fetch `/packs/catalog.json`, merge with built-ins (catalog wins on id). Idempotent. */
	async ensureLoaded(): Promise<void> {
		if (this.loaded) return;
		if (this.loading) return this.loading;
		this.loading = (async () => {
			try {
				const res = await fetch('/packs/catalog.json', { cache: 'no-cache' });
				const raw = (await res.json()) as Partial<CatalogEntry>[];
				const fromCatalog = raw
					.filter(
						(e): e is Partial<CatalogEntry> & { id: string; name: string } =>
							typeof e.id === 'string' && typeof e.name === 'string'
					)
					.map(normalizeEntry);
				const catalogIds = new Set(fromCatalog.map((e) => e.id));
				const missingBuiltins = BUILTIN_DICTIONARIES.filter((b) => !catalogIds.has(b.id));
				this.entries = [...missingBuiltins, ...fromCatalog];
				this.loaded = true;
			} catch {
				console.error('[taijobi] Failed to load pack catalog');
				// Keep built-in dictionaries seeded — don't mark loaded so retry can happen.
			} finally {
				this.loading = null;
			}
		})();
		return this.loading;
	}
}

export const catalogStore = new CatalogStore();
