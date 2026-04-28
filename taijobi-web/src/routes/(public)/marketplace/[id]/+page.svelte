<script lang="ts">
	import ArrowBack from '$lib/icons/ArrowBack.svelte';
	import Dictionary from '$lib/icons/Dictionary.svelte';
	import Language from '$lib/icons/Language.svelte';
	import Download from '$lib/icons/Download.svelte';
	import Book from '$lib/icons/Book.svelte';
	import { page } from '$app/state';
	import { tagLabel, tagBadgeClass } from '$lib/catalog-store.svelte';
	import { getPack, type Pack, type PackVocab } from '$lib/marketplace.remote';
	import { error } from '@sveltejs/kit';

	const result = await getPack(page.params.id ?? '');

	// Handle not found — throw 404 so the error page renders properly
	if (!result.entry) {
		throw error(404, `Paket "${page.params.id}" nicht gefunden`);
	}

	let entry = $derived(result.entry);
	let pack = $derived<Pack | null>(result.pack);

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

	function sizeLabel(): string {
		if (entry.kind === 'dictionary') return `~${entry.size_mb ?? 0} MB`;
		return `${(entry.word_count ?? 0).toLocaleString('de-DE')} Wörter`;
	}

	let totalVocab = $derived(
		pack ? pack.lessons.reduce((sum, l) => sum + (l.vocabulary?.length ?? 0), 0) : 0
	);

	let sampleVocab = $derived<PackVocab[]>(
		pack
			? pack.lessons
					.flatMap((l) => l.vocabulary ?? [])
					.slice(0, 8)
			: []
	);

	const ABS_URL = 'https://taijobi.com';

	let metaDescription = $derived(
		entry.description ||
			(entry.kind === 'dictionary'
				? `${entry.name} für Taijobi — offline-fähiges Wörterbuch (~${entry.size_mb ?? 0} MB).`
				: `${entry.name} — ${(entry.word_count ?? 0).toLocaleString('de-DE')} Vokabeln (${languagePairLabel(entry.language_pair)}). Offline lernen mit Taijobi, Spaced Repetition, kein Konto nötig.`)
	);
	let metaTitle = $derived(`${entry.name} — Taijobi-Marktplatz`);
	let canonical = $derived(`${ABS_URL}/marketplace/${entry.id}`);
</script>

<svelte:head>
	<title>{metaTitle}</title>
	<meta name="description" content={metaDescription} />
	<meta property="og:type" content="website" />
	<meta property="og:title" content={metaTitle} />
	<meta property="og:description" content={metaDescription} />
	<meta property="og:image" content="{ABS_URL}/og/{entry.id}.png" />
	<meta property="og:url" content={canonical} />
	<meta name="twitter:card" content="summary_large_image" />
	<meta name="twitter:title" content={metaTitle} />
	<meta name="twitter:description" content={metaDescription} />
	<meta name="twitter:image" content="{ABS_URL}/og/{entry.id}.png" />
	<link rel="canonical" href={canonical} />
</svelte:head>

<!-- Breadcrumb -->
<nav class="pt-6 pb-2">
	<a
		href="/marketplace"
		class="inline-flex items-center gap-1 text-sm font-medium text-slate-500 transition-colors hover:text-primary dark:text-slate-400"
	>
		<ArrowBack />
		Marktplatz
	</a>
</nav>

<!-- Hero -->
<section class="pt-4 pb-8">
	<div class="flex flex-col gap-6 md:flex-row md:items-start">
		<div class="flex size-24 shrink-0 items-center justify-center rounded-2xl bg-primary/10 md:size-28">
			{#if entry.kind === 'dictionary'}
				<Dictionary class="text-5xl text-primary md:text-6xl" />
			{:else}
				<Language class="text-5xl text-primary md:text-6xl" />
			{/if}
		</div>
		<div class="min-w-0 flex-1">
			<div class="mb-2 flex flex-wrap items-center gap-2">
				<span class="rounded-md px-1.5 py-0.5 text-[10px] font-bold uppercase tracking-wider {tagBadgeClass(entry.tag)}">
					{tagLabel(entry.tag)}
				</span>
				<span class="text-xs font-medium uppercase tracking-wider text-slate-400 dark:text-slate-500">
					{entry.kind === 'dictionary' ? 'Wörterbuch' : 'Lehrbuch'}
				</span>
			</div>
			<h1 class="mb-3 text-4xl font-black tracking-tight text-slate-900 dark:text-slate-100 md:text-5xl">
				{entry.name}
			</h1>
			<p class="mb-4 text-base font-medium text-primary dark:text-accent">
				{languagePairLabel(entry.language_pair)} &bull; {sizeLabel()}
			</p>
			{#if entry.description}
				<p class="mb-4 max-w-2xl text-base leading-relaxed text-slate-600 dark:text-slate-300">
					{entry.description}
				</p>
			{/if}
			<div class="flex flex-wrap gap-3">
				<a
					href="/packs?install={entry.id}"
					class="inline-flex items-center gap-2 rounded-xl bg-primary px-5 py-3 text-sm font-bold text-white shadow-sm transition-colors hover:bg-primary/90"
				>
					<Download />
					In Taijobi installieren
				</a>
				<a
					href="/marketplace"
					class="inline-flex items-center gap-2 rounded-xl border border-slate-200 bg-white px-5 py-3 text-sm font-bold text-slate-700 transition-colors hover:bg-slate-50 dark:border-white/10 dark:bg-white/5 dark:text-slate-200 dark:hover:bg-white/10"
				>
					Andere Pakete ansehen
				</a>
			</div>
		</div>
	</div>
</section>

<!-- Stats strip (content packs) -->
{#if pack}
	<section class="grid grid-cols-3 gap-3 rounded-2xl border border-slate-100 bg-white p-4 dark:border-white/5 dark:bg-white/5">
		<div class="text-center">
			<p class="text-2xl font-extrabold text-primary dark:text-accent">{pack.lessons.length}</p>
			<p class="text-xs uppercase tracking-wider text-slate-400 dark:text-slate-500">Lektionen</p>
		</div>
		<div class="border-x border-slate-100 text-center dark:border-white/5">
			<p class="text-2xl font-extrabold text-primary dark:text-accent">
				{totalVocab.toLocaleString('de-DE')}
			</p>
			<p class="text-xs uppercase tracking-wider text-slate-400 dark:text-slate-500">Vokabeln</p>
		</div>
		<div class="text-center">
			<p class="text-2xl font-extrabold text-primary dark:text-accent">v{pack.version}</p>
			<p class="text-xs uppercase tracking-wider text-slate-400 dark:text-slate-500">Version</p>
		</div>
	</section>
{/if}

<!-- Sample vocab preview -->
{#if sampleVocab.length > 0}
	<section class="mt-10">
		<h2 class="mb-4 flex items-center gap-2 text-lg font-bold text-slate-900 dark:text-slate-100">
			<Book class="text-primary" />
			Vorschau
		</h2>
		<div class="overflow-hidden rounded-2xl border border-slate-100 bg-white shadow-sm dark:border-white/5 dark:bg-white/5">
			<table class="w-full text-left text-sm">
				<thead class="bg-slate-50 dark:bg-white/5">
					<tr>
						<th class="px-4 py-3 text-xs font-bold uppercase tracking-wider text-primary dark:text-accent">
							Wort
						</th>
						{#if sampleVocab.some((v) => v.pinyin)}
							<th class="px-4 py-3 text-xs font-bold uppercase tracking-wider text-primary dark:text-accent">
								Pinyin
							</th>
						{/if}
						<th class="px-4 py-3 text-xs font-bold uppercase tracking-wider text-primary dark:text-accent">
							&Uuml;bersetzung
						</th>
					</tr>
				</thead>
				<tbody>
					{#each sampleVocab as v, i (i)}
						<tr class="border-t border-slate-100 dark:border-white/5">
							<td class="px-4 py-3 text-base font-medium text-slate-900 dark:text-slate-100">
								{v.word}
							</td>
							{#if sampleVocab.some((s) => s.pinyin)}
								<td class="px-4 py-3 text-sm text-primary/80 dark:text-accent">
									{v.pinyin ?? ''}
								</td>
							{/if}
							<td class="max-w-md truncate px-4 py-3 text-sm text-slate-600 dark:text-slate-300">
								{v.translation}
							</td>
						</tr>
					{/each}
				</tbody>
			</table>
		</div>
		<p class="mt-2 text-center text-xs text-slate-400 dark:text-slate-500">
			Auszug aus {totalVocab.toLocaleString('de-DE')} Vokabeln &mdash; nach Installation komplett verf&uuml;gbar
		</p>
	</section>
{/if}

<!-- Lesson list -->
{#if pack && pack.lessons.length > 0}
	<section class="mt-10">
		<h2 class="mb-4 text-lg font-bold text-slate-900 dark:text-slate-100">Lektionen</h2>
		<div class="space-y-2">
			{#each pack.lessons as lesson, idx (lesson.id)}
				<div class="flex items-center justify-between rounded-xl border border-slate-100 bg-white px-4 py-3 dark:border-white/5 dark:bg-white/5">
					<div class="flex min-w-0 items-center gap-3">
						<span class="flex size-8 shrink-0 items-center justify-center rounded-lg bg-primary/10 text-xs font-bold text-primary dark:text-accent">
							{idx + 1}
						</span>
						<span class="truncate text-sm font-medium text-slate-700 dark:text-slate-200">
							{lesson.title}
						</span>
					</div>
					<span class="shrink-0 text-xs text-slate-400 dark:text-slate-500">
						{lesson.vocabulary?.length ?? 0} W&ouml;rter
					</span>
				</div>
			{/each}
		</div>
	</section>
{/if}

<!-- Dictionary detail block (no sample vocab) -->
{#if entry.kind === 'dictionary'}
	<section class="mt-10 rounded-2xl border border-slate-100 bg-white p-6 dark:border-white/5 dark:bg-white/5">
		<h2 class="mb-3 text-lg font-bold text-slate-900 dark:text-slate-100">&Uuml;ber dieses W&ouml;rterbuch</h2>
		<p class="text-sm leading-relaxed text-slate-600 dark:text-slate-300">
			{#if entry.id === 'dict-zh'}
				CC-CEDICT (124.000 Eintr&auml;ge), Strichfolge-Animationen aus &laquo;Make Me a Hanzi&raquo;
				und Zeichenzerlegung. Wird beim ersten Start in den Browser-Speicher (OPFS) geladen
				und l&auml;uft danach komplett offline.
			{:else if entry.id === 'dict-en'}
				Wiktionary-Definitionen f&uuml;r Englisch, kompiliert aus Wiktextract
				(166.000 Eintr&auml;ge). Wird einmalig heruntergeladen und l&auml;uft offline.
			{:else if entry.id === 'dict-de'}
				Wiktionary-Definitionen f&uuml;r Deutsch, kompiliert aus Wiktextract.
				Wird einmalig heruntergeladen und l&auml;uft offline.
			{:else}
				Offline-fähiges Wörterbuch für Taijobi.
			{/if}
		</p>
	</section>
{/if}

<!-- Sources / attribution -->
{#if entry.sources && entry.sources.length > 0}
	<section class="mt-8">
		<h2 class="mb-3 text-sm font-bold uppercase tracking-wider text-primary dark:text-accent">
			Quellen
		</h2>
		<ul class="space-y-2">
			{#each entry.sources as source (source.url)}
				<li class="flex items-start gap-2 rounded-xl border border-slate-100 bg-white px-4 py-3 dark:border-white/5 dark:bg-white/5">
					<div class="min-w-0 flex-1">
						<a
							href={source.url}
							target="_blank"
							rel="noopener noreferrer"
							class="text-sm font-medium text-primary underline-offset-2 hover:underline dark:text-accent"
						>
							{source.name}
						</a>
						{#if source.license}
							<span class="ml-2 text-xs text-slate-400 dark:text-slate-500">
								&middot; {source.license}
							</span>
						{/if}
						<p class="truncate text-xs text-slate-400 dark:text-slate-500">{source.url}</p>
					</div>
				</li>
			{/each}
		</ul>
		<p class="mt-2 text-xs text-slate-400 dark:text-slate-500">
			Inhalte stammen von Drittanbietern und sind unter der jeweiligen Lizenz verf&uuml;gbar.
		</p>
	</section>
{/if}

<!-- Bottom CTA -->
<section class="mt-12 rounded-2xl bg-primary/5 p-8 text-center dark:bg-primary/10">
	<h2 class="mb-2 text-xl font-bold text-slate-900 dark:text-slate-100">
		Bereit zum Lernen?
	</h2>
	<p class="mx-auto mb-4 max-w-xl text-sm text-slate-500 dark:text-slate-400">
		&Ouml;ffne Taijobi und installiere &laquo;{entry.name}&raquo; mit einem Klick.
		Alles l&auml;uft lokal, kein Konto n&ouml;tig.
	</p>
	<a
		href="/packs?install={entry.id}"
		class="inline-flex items-center gap-2 rounded-full bg-primary px-6 py-3 text-sm font-bold text-white shadow-sm transition-colors hover:bg-primary/90"
	>
		<Download />
		In Taijobi installieren
	</a>
</section>
