/**
 * Marketplace data — single source of truth for catalog + pack JSON loads.
 *
 * Both queries are `prerender(...)` so the data is baked into static .json
 * files at build time and served from CDN on client navigation. Net effect
 * is identical to a `+page.ts` load() that fetches static assets, but
 * centralised: the marketplace index, detail page, and the in-app
 * catalog-store all read through these functions.
 */
import { prerender } from '$app/server';
import { error } from '@sveltejs/kit';
import * as v from 'valibot';
import {
	normalizeEntry,
	type CatalogEntry,
	type CatalogKind,
	type CatalogTag
} from '$lib/catalog-store.svelte';

const SourceSchema = v.object({
	name: v.string(),
	url: v.string(),
	license: v.optional(v.string())
});

const CatalogEntrySchema = v.object({
	id: v.string(),
	kind: v.optional(v.picklist(['content', 'dictionary'] as const satisfies CatalogKind[])),
	tag: v.optional(v.string()),
	name: v.string(),
	language_pair: v.optional(v.string()),
	description: v.optional(v.string()),
	word_count: v.optional(v.number()),
	size_mb: v.optional(v.number()),
	added_at: v.optional(v.string()),
	sources: v.optional(v.array(SourceSchema))
});

const CatalogSchema = v.array(CatalogEntrySchema);

const VocabSchema = v.object({
	word: v.string(),
	pinyin: v.optional(v.string()),
	translation: v.string()
});

const LessonSchema = v.object({
	id: v.string(),
	title: v.string(),
	sort_order: v.number(),
	vocabulary: v.optional(v.array(VocabSchema))
});

const PackSchema = v.object({
	id: v.string(),
	name: v.string(),
	version: v.number(),
	language_pair: v.string(),
	lessons: v.array(LessonSchema)
});

export type PackVocab = v.InferOutput<typeof VocabSchema>;
export type PackLesson = v.InferOutput<typeof LessonSchema>;
export type Pack = v.InferOutput<typeof PackSchema>;

async function readCatalogFile(): Promise<CatalogEntry[]> {
	const fs = await import('node:fs/promises');
	const path = await import('node:path');
	const file = path.join(process.cwd(), 'static', 'packs', 'catalog.json');
	const raw = JSON.parse(await fs.readFile(file, 'utf-8'));
	const parsed = v.parse(CatalogSchema, raw);
	return parsed.map((e) =>
		normalizeEntry({
			...e,
			tag: (e.tag ?? 'official') as CatalogTag
		})
	);
}

async function readPackFile(id: string): Promise<Pack | null> {
	const fs = await import('node:fs/promises');
	const path = await import('node:path');
	try {
		const file = path.join(process.cwd(), 'static', 'packs', `${id}.json`);
		const raw = JSON.parse(await fs.readFile(file, 'utf-8'));
		return v.parse(PackSchema, raw);
	} catch {
		return null;
	}
}

/** Full marketplace catalog. Baked into a static .json at build time. */
export const getCatalog = prerender(async () => {
	return readCatalogFile();
});

/**
 * One catalog entry plus its full pack JSON (vocab + lessons), or `null`
 * pack for dictionaries. Inputs are enumerated from catalog.json at build
 * time so every entry gets its own static .json file.
 */
export const getPack = prerender(
	v.string(),
	async (id) => {
		const catalog = await readCatalogFile();
		const entry = catalog.find((e) => e.id === id);
		if (!entry) throw error(404, `Paket "${id}" nicht gefunden`);
		const pack = entry.kind === 'content' ? await readPackFile(id) : null;
		return { entry, pack };
	},
	{
		inputs: async () => {
			const catalog = await readCatalogFile();
			return catalog.map((e) => e.id);
		}
	}
);
