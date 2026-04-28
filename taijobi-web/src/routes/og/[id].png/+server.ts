import { error } from '@sveltejs/kit';
import { Resvg } from '@resvg/resvg-js';
import { buildOgSvg } from '$lib/og-template';
import { tagLabel, normalizeEntry, type CatalogEntry } from '$lib/catalog-store.svelte';

export const prerender = true;

async function readCatalog(): Promise<CatalogEntry[]> {
	const fs = await import('node:fs/promises');
	const path = await import('node:path');
	const file = path.join(process.cwd(), 'static', 'packs', 'catalog.json');
	const raw = JSON.parse(await fs.readFile(file, 'utf-8')) as Partial<CatalogEntry>[];
	return raw
		.filter(
			(e): e is Partial<CatalogEntry> & { id: string; name: string } =>
				typeof e.id === 'string' && typeof e.name === 'string'
		)
		.map(normalizeEntry);
}

// Enumerate all known pack ids at build time. Remote functions need a
// request store and can't be called from `entries()`, so read the
// catalog file directly here.
export const entries = async () => {
	const catalog = await readCatalog();
	return catalog.map((e) => ({ id: e.id }));
};

const LANG_MAP: Record<string, string> = {
	zh: 'Chinesisch',
	en: 'Englisch',
	de: 'Deutsch',
	ar: 'Arabisch',
	'zh-en': 'Chinesisch → Englisch',
	'zh-de': 'Chinesisch → Deutsch',
	'ar-de': 'Arabisch → Deutsch',
	'de-en': 'Deutsch → Englisch',
	'en-de': 'Englisch → Deutsch'
};

export const GET = async ({ params }) => {
	const id = params.id ?? '';
	const catalog = await readCatalog();
	const entry = catalog.find((e) => e.id === id);
	if (!entry) throw error(404, `Paket "${id}" nicht im Katalog`);

	const langLabel = LANG_MAP[entry.language_pair] ?? entry.language_pair;
	const sizeLabel =
		entry.kind === 'dictionary'
			? `~${entry.size_mb ?? 0} MB`
			: `${(entry.word_count ?? 0).toLocaleString('de-DE')} Wörter`;

	const svg = buildOgSvg({
		heading: entry.name,
		subtitle: `${langLabel} · ${sizeLabel}`,
		tag: tagLabel(entry.tag)
	});

	const png = new Resvg(svg, { fitTo: { mode: 'width', value: 1200 } }).render().asPng();
	return new Response(png as unknown as BodyInit, {
		headers: {
			'content-type': 'image/png',
			'cache-control': 'public, max-age=31536000, immutable'
		}
	});
};
