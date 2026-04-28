<script lang="ts">
	import Search from '$lib/icons/Search.svelte';
	import Dictionary from '$lib/icons/Dictionary.svelte';
	import Language from '$lib/icons/Language.svelte';
	import Inventory2 from '$lib/icons/Inventory2.svelte';
	import ChevronRight from '$lib/icons/ChevronRight.svelte';
	import SwapVert from '$lib/icons/SwapVert.svelte';
	import {
		tagLabel,
		tagBadgeClass,
		type CatalogEntry,
		type CatalogKind
	} from '$lib/catalog-store.svelte';
	import { getCatalog } from '$lib/marketplace.remote';

	const entries = await getCatalog();

	type SortKey = 'featured' | 'newest' | 'oldest' | 'alpha' | 'alpha-desc' | 'largest';

	let searchQuery = $state('');
	let kindFilter = $state<'all' | CatalogKind | 'community'>('all');
	let sortKey = $state<SortKey>('featured');

	const SORT_OPTIONS: { value: SortKey; label: string }[] = [
		{ value: 'featured', label: 'Empfohlen' },
		{ value: 'newest', label: 'Neueste zuerst' },
		{ value: 'oldest', label: '&Auml;lteste zuerst' },
		{ value: 'alpha', label: 'A&ndash;Z' },
		{ value: 'alpha-desc', label: 'Z&ndash;A' },
		{ value: 'largest', label: 'Gr&ouml;&szlig;te zuerst' }
	];

	const FILTERS: { value: 'all' | CatalogKind | 'community'; label: string }[] = [
		{ value: 'all', label: 'Alle' },
		{ value: 'dictionary', label: 'W&ouml;rterb&uuml;cher' },
		{ value: 'content', label: 'Lehrb&uuml;cher' },
		{ value: 'community', label: 'Community' }
	];

	function matchesSearch(entry: CatalogEntry, q: string): boolean {
		if (!q) return true;
		const hay = `${entry.name} ${entry.description} ${entry.language_pair}`.toLowerCase();
		return hay.includes(q.toLowerCase());
	}

	function matchesFilter(entry: CatalogEntry, f: typeof kindFilter): boolean {
		if (f === 'all') return true;
		if (f === 'community') return entry.tag === 'community';
		return entry.kind === f;
	}

	function sizeForSort(entry: CatalogEntry): number {
		if (entry.kind === 'dictionary') return (entry.size_mb ?? 0) * 1000;
		return entry.word_count ?? 0;
	}

	function compare(a: CatalogEntry, b: CatalogEntry, key: SortKey): number {
		switch (key) {
			case 'featured':
				return 0;
			case 'newest':
				return (b.added_at ?? '').localeCompare(a.added_at ?? '');
			case 'oldest':
				return (a.added_at ?? '').localeCompare(b.added_at ?? '');
			case 'alpha':
				return a.name.localeCompare(b.name, 'de');
			case 'alpha-desc':
				return b.name.localeCompare(a.name, 'de');
			case 'largest':
				return sizeForSort(b) - sizeForSort(a);
		}
	}

	let filtered = $derived(
		entries
			.filter((e) => matchesFilter(e, kindFilter) && matchesSearch(e, searchQuery.trim()))
			.toSorted((a, b) => compare(a, b, sortKey))
	);

	function languagePairLabel(pair: string): string {
		const map: Record<string, string> = {
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
		return map[pair] ?? pair;
	}

	function sizeLabel(entry: CatalogEntry): string {
		if (entry.kind === 'dictionary') return `~${entry.size_mb ?? 0} MB`;
		return `${(entry.word_count ?? 0).toLocaleString('de-DE')} Wörter`;
	}
</script>

<svelte:head>
	<title>Pakete-Marktplatz &mdash; Taijobi</title>
	<meta
		name="description"
		content="Durchsuche Vokabel-Pakete und Wörterbücher für Taijobi. HSK-Stufen, Lóng neu, Community-Decks und CC-CEDICT/Wiktionary-Wörterbücher — alle offline lauffähig."
	/>
	<meta property="og:type" content="website" />
	<meta property="og:title" content="Pakete-Marktplatz &mdash; Taijobi" />
	<meta
		property="og:description"
		content="Vokabel-Pakete und Wörterbücher für Taijobi. HSK, Lóng neu, Community-Decks. Offline-first, kein Konto nötig."
	/>
	<meta property="og:image" content="/og/default.png" />
	<meta property="og:url" content="https://taijobi.com/marketplace" />
	<meta name="twitter:card" content="summary_large_image" />
	<meta name="twitter:title" content="Pakete-Marktplatz &mdash; Taijobi" />
	<meta
		name="twitter:description"
		content="Vokabel-Pakete und Wörterbücher für Taijobi. Offline-first, kein Konto nötig."
	/>
	<meta name="twitter:image" content="/og/default.png" />
	<link rel="canonical" href="https://taijobi.com/marketplace" />
</svelte:head>

<!-- Hero -->
<section class="pt-12 pb-8 text-center">
	<div class="mb-5 inline-flex size-16 items-center justify-center rounded-2xl bg-primary/10">
		<Inventory2 class="text-3xl text-primary" />
	</div>
	<h1 class="mb-4 text-4xl font-black tracking-tight text-slate-900 dark:text-slate-100 md:text-5xl">
		Pakete-Marktplatz
	</h1>
	<p class="mx-auto max-w-2xl text-base leading-relaxed text-slate-500 dark:text-slate-400 md:text-lg">
		Durchsuche kuratierte Vokabel-Pakete und W&ouml;rterb&uuml;cher.
		Alle laufen lokal in deinem Browser &mdash; offline-first, ohne Konto.
	</p>
</section>

<!-- Search + sort -->
<section class="space-y-3">
	<div class="grid grid-cols-1 gap-3 sm:grid-cols-[1fr_auto]">
		<div class="relative">
			<Search class="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-slate-400 dark:text-slate-500" />
			<input
				type="search"
				bind:value={searchQuery}
				placeholder="Pakete durchsuchen"
				class="w-full rounded-xl border border-slate-200 bg-white py-2.5 pl-10 pr-3 text-sm text-slate-700 placeholder:text-slate-400 focus:border-primary focus:outline-none dark:border-white/10 dark:bg-white/5 dark:text-slate-200 dark:placeholder:text-slate-500"
			/>
		</div>
		<div class="relative">
			<SwapVert class="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-slate-400 dark:text-slate-500" />
			<select
				bind:value={sortKey}
				class="w-full appearance-none rounded-xl border border-slate-200 bg-white py-2.5 pl-10 pr-8 text-sm font-medium text-slate-700 focus:border-primary focus:outline-none dark:border-white/10 dark:bg-white/5 dark:text-slate-200 sm:w-56"
			>
				{#each SORT_OPTIONS as opt (opt.value)}
					<option value={opt.value}>{@html opt.label}</option>
				{/each}
			</select>
			<ChevronRight class="pointer-events-none absolute right-3 top-1/2 -translate-y-1/2 rotate-90 text-slate-400 dark:text-slate-500" />
		</div>
	</div>

	<div class="flex flex-wrap gap-2">
		{#each FILTERS as chip (chip.value)}
			<button
				onclick={() => (kindFilter = chip.value)}
				class="rounded-full px-3 py-1.5 text-xs font-bold transition-colors {kindFilter === chip.value
					? 'bg-primary text-white'
					: 'bg-slate-100 text-slate-600 hover:bg-slate-200 dark:bg-white/5 dark:text-slate-300 dark:hover:bg-white/10'}"
			>
				{@html chip.label}
			</button>
		{/each}
	</div>
</section>

<!-- Results count -->
<p class="mt-6 text-xs uppercase tracking-wider text-slate-400 dark:text-slate-500">
	{filtered.length} {filtered.length === 1 ? 'Paket' : 'Pakete'}
</p>

<!-- Grid -->
{#if filtered.length === 0}
	<div class="mt-6 rounded-2xl border border-slate-100 bg-white p-12 text-center dark:border-white/5 dark:bg-white/5">
		<p class="text-sm text-slate-500 dark:text-slate-400">Keine Treffer.</p>
	</div>
{:else}
	<div class="mt-3 grid grid-cols-1 gap-4 md:grid-cols-2">
		{#each filtered as entry (entry.id)}
			<a
				href="/marketplace/{entry.id}"
				class="group flex flex-col rounded-2xl border border-slate-100 bg-white p-5 shadow-sm transition-all hover:border-primary/40 hover:shadow-md dark:border-white/5 dark:bg-white/5 dark:hover:border-primary/40"
			>
				<div class="flex items-start gap-4">
					<div
						class="flex size-14 shrink-0 items-center justify-center rounded-xl {entry.kind === 'dictionary'
							? 'bg-primary/10'
							: 'bg-primary/5 dark:bg-primary/10'}"
					>
						{#if entry.kind === 'dictionary'}
							<Dictionary class="text-2xl text-primary" />
						{:else}
							<Language class="text-2xl text-primary" />
						{/if}
					</div>
					<div class="min-w-0 flex-1">
						<div class="mb-1 flex flex-wrap items-center gap-2">
							<h3 class="truncate text-lg font-bold text-slate-900 dark:text-slate-100">
								{entry.name}
							</h3>
							<span class="shrink-0 rounded-md px-1.5 py-0.5 text-[10px] font-bold uppercase tracking-wider {tagBadgeClass(entry.tag)}">
								{tagLabel(entry.tag)}
							</span>
						</div>
						<p class="text-xs font-medium text-primary dark:text-accent">
							{languagePairLabel(entry.language_pair)}
						</p>
						<p class="text-xs text-slate-400 dark:text-slate-500">{sizeLabel(entry)}</p>
					</div>
				</div>
				{#if entry.description}
					<p class="mt-3 line-clamp-2 text-sm text-slate-600 dark:text-slate-300">
						{entry.description}
					</p>
				{/if}
				<div class="mt-4 flex items-center justify-end text-sm font-medium text-primary transition-transform group-hover:translate-x-1 dark:text-accent">
					Details
					<ChevronRight class="ml-1" />
				</div>
			</a>
		{/each}
	</div>
{/if}

<!-- CTA strip -->
<section class="mt-12 rounded-2xl bg-primary/5 p-6 text-center dark:bg-primary/10">
	<h2 class="mb-2 text-lg font-bold text-slate-900 dark:text-slate-100">
		Eigenes Paket teilen?
	</h2>
	<p class="mx-auto mb-4 max-w-xl text-sm text-slate-500 dark:text-slate-400">
		Importiere deine CSV/TSV oder Anki-Decks, exportiere als Community-Paket
		und reiche einen PR ein.
	</p>
	<a
		href="/packs"
		class="inline-flex items-center gap-2 rounded-full bg-primary px-5 py-2 text-sm font-bold text-white transition-colors hover:bg-primary/90"
	>
		Eigenes Paket importieren
		<ChevronRight />
	</a>
</section>
