<script lang="ts">
	import {
		getDueCards,
		getDueCardsFiltered,
		getDueCountFiltered,
		getPacks,
		reviewCard,
		type Card,
		type Pack
	} from '$lib/wasm';
	import { speak } from '$lib/speak';
	import { page } from '$app/state';

	type DrillPhase = 'picking' | 'question' | 'answer' | 'complete';

	let cards: Card[] = $state([]);
	let index = $state(0);
	let phase: DrillPhase = $state('picking');
	let input = $state('');
	let reviewed = $state(0);
	let activeFilter = $state('');
	let filterLabel = $state('');

	// Sources for the picker
	let packs: Pack[] = $state([]);

	interface DrillSource {
		id: string;
		label: string;
		count: number;
	}

	let sources: DrillSource[] = $state([]);

	function buildSources() {
		packs = getPacks();
		const all: DrillSource[] = [];

		const totalDue = getDueCountFiltered('');
		if (totalDue > 0) all.push({ id: '', label: 'Alle Karten', count: totalDue });

		for (const pack of packs) {
			const count = getDueCountFiltered(pack.id);
			if (count > 0) all.push({ id: pack.id, label: pack.name, count });
		}

		const lexCount = getDueCountFiltered('lexicon');
		if (lexCount > 0) all.push({ id: 'lexicon', label: 'Lexikon', count: lexCount });

		// Seed cards (no pack_id, not lexicon) — check if "Alle" > sum of others
		sources = all;
	}

	// If navigated with ?pack=xxx, skip picker
	function init() {
		const urlFilter = page.url.searchParams.get('pack');
		if (urlFilter) {
			startDrill(urlFilter, urlFilter);
		} else {
			buildSources();
			phase = 'picking';
		}
	}

	init();

	function startDrill(filter: string, label: string) {
		activeFilter = filter;
		filterLabel = label;
		cards = filter ? getDueCardsFiltered(filter, 50) : getDueCards(50);
		index = 0;
		phase = cards.length > 0 ? 'question' : 'complete';
		input = '';
		reviewed = 0;
	}

	let card = $derived(cards[index] as Card | undefined);
	let total = $derived(cards.length);

	function reveal() {
		if (phase === 'question') phase = 'answer';
	}

	async function rate(rating: number) {
		if (!card) return;
		await reviewCard(card.id, rating);
		reviewed++;
		index++;
		input = '';
		phase = index >= total ? 'complete' : 'question';
	}

	function formatInterval(days: number): string {
		if (days < 1) return '<1d';
		if (days < 30) return `${Math.round(days)}d`;
		if (days < 365) return `${Math.round(days / 30)}mo`;
		return `${(days / 365).toFixed(1)}y`;
	}

	function handleKeydown(e: KeyboardEvent) {
		if (phase === 'question' && e.key === 'Enter') {
			reveal();
		} else if (phase === 'answer') {
			if (e.key === '1') rate(1);
			else if (e.key === '2') rate(2);
			else if (e.key === '3') rate(3);
			else if (e.key === '4') rate(4);
		}
	}
</script>

<svelte:window onkeydown={handleKeydown} />

{#if phase === 'picking'}
	<!-- Source picker -->
	<section class="mt-6">
		<h2 class="mb-4 text-lg font-bold text-slate-900">Was m&ouml;chtest du &uuml;ben?</h2>
		<div class="space-y-3">
			{#each sources as source (source.id)}
				<button
					onclick={() => startDrill(source.id, source.label)}
					class="flex w-full items-center justify-between rounded-2xl border border-slate-100 bg-white p-4 shadow-sm transition-colors hover:bg-primary/5"
				>
					<div class="flex items-center gap-3">
						<span class="material-symbols-outlined text-primary">
							{source.id === '' ? 'layers' : source.id === 'lexicon' ? 'book' : 'inventory_2'}
						</span>
						<span class="font-bold text-slate-900">{source.label}</span>
					</div>
					<span class="rounded-full bg-primary/10 px-3 py-1 text-sm font-bold text-primary">
						{source.count}
					</span>
				</button>
			{/each}
		</div>
		{#if sources.length === 0}
			<div class="rounded-2xl border border-slate-100 bg-white p-8 text-center shadow-sm">
				<p class="text-2xl font-bold text-slate-900">Alles erledigt!</p>
				<p class="mt-2 text-sm text-slate-500">Keine Karten f&auml;llig.</p>
			</div>
		{/if}
	</section>
{:else if phase === 'complete'}
	<div class="flex flex-col items-center pt-20">
		<div
			class="flex size-16 items-center justify-center rounded-full bg-primary-light text-primary"
		>
			<span class="material-symbols-outlined text-[32px]">check_circle</span>
		</div>
		<p class="mt-4 text-2xl font-bold text-slate-900">Sitzung abgeschlossen</p>
		<p class="mt-2 text-sm text-slate-500">{reviewed} Karten gelernt</p>
		<div class="mt-8 flex gap-3">
			<button
				onclick={() => { buildSources(); phase = 'picking'; }}
				class="rounded-lg bg-primary px-8 py-3 font-semibold text-white shadow-md shadow-primary/20 transition-all hover:bg-primary/90"
			>
				Weiter &uuml;ben
			</button>
			<a
				href="/"
				class="rounded-lg border border-slate-200 px-8 py-3 font-semibold text-slate-600 transition-all hover:bg-slate-50"
			>
				Zur&uuml;ck
			</a>
		</div>
	</div>
{:else if card}
	<!-- Progress counter -->
	<div class="mb-8 mt-4 text-center">
		{#if filterLabel}
			<p class="mb-1 text-xs font-bold uppercase tracking-wider text-primary">{filterLabel}</p>
		{/if}
		<p class="text-lg font-bold text-slate-900">{index + 1} / {total}</p>
	</div>

	<!-- Card -->
	<div class="flex flex-col items-center justify-center">
		<div class="mb-8 text-center">
			{#if card.language === 'zh'}
				<h1 class="chinese-char mb-2 text-6xl font-bold tracking-tight text-slate-900">
					{card.word}
				</h1>
				<div class="flex items-center justify-center gap-3">
					{#if card.pinyin}
						<p class="text-lg font-medium text-primary">{card.pinyin}</p>
					{/if}
					<button
						onclick={() => speak(card.word, card.language)}
						class="flex items-center justify-center rounded-full bg-primary/10 p-2 text-primary transition-colors hover:bg-primary/20"
					>
						<span class="material-symbols-outlined text-xl">volume_up</span>
					</button>
				</div>
			{:else}
				<div class="flex items-center justify-center gap-3">
					<h1 class="text-4xl font-bold tracking-tight text-slate-900">{card.word}</h1>
					<button
						onclick={() => speak(card.word, card.language)}
						class="flex items-center justify-center rounded-full bg-primary/10 p-2 text-primary transition-colors hover:bg-primary/20"
					>
						<span class="material-symbols-outlined text-xl">volume_up</span>
					</button>
				</div>
			{/if}
		</div>

		<!-- Input area -->
		<div class="w-full max-w-md space-y-4">
			{#if phase === 'question'}
				<div class="relative">
					<input
						type="text"
						bind:value={input}
						placeholder="&Uuml;bersetzung eingeben..."
						class="h-14 w-full rounded-xl border-2 border-primary bg-primary-light text-center text-lg text-slate-900 placeholder-primary/60 outline-none focus:ring-2 focus:ring-primary"
					/>
				</div>
				<button
					onclick={reveal}
					class="h-14 w-full rounded-xl bg-primary text-lg font-bold text-white transition-all hover:opacity-90 active:scale-[0.98]"
				>
					Pr&uuml;fen
				</button>
			{:else}
				<!-- Answer revealed -->
				<div
					class="flex w-full items-stretch overflow-hidden rounded-xl border-2 border-primary bg-white"
				>
					<div class="flex-1 p-4 text-xl font-semibold text-primary">
						{card.translation ?? '—'}
					</div>
					<div class="flex items-center bg-primary/5 px-4 text-primary">
						<span class="material-symbols-outlined text-3xl font-bold">check_circle</span>
					</div>
				</div>

				{#if input}
					<p class="text-center text-sm text-slate-400">
						Deine Antwort: <span class="font-medium">{input}</span>
					</p>
				{/if}

				<!-- Rating buttons -->
				<div class="mt-6 grid w-full grid-cols-4 gap-3">
					<button
						onclick={() => rate(1)}
						class="flex flex-col items-center justify-center rounded-xl border border-red-200 bg-red-50 py-4 transition-all hover:brightness-95"
					>
						<span class="text-sm font-bold uppercase tracking-tighter text-red-700"
							>Nochmal</span
						>
						<span class="mt-1 text-xs text-red-500"
							>{formatInterval(card.intervals.again)}</span
						>
					</button>
					<button
						onclick={() => rate(2)}
						class="flex flex-col items-center justify-center rounded-xl border border-amber-200 bg-amber-50 py-4 transition-all hover:brightness-95"
					>
						<span class="text-sm font-bold uppercase tracking-tighter text-amber-700"
							>Schwer</span
						>
						<span class="mt-1 text-xs text-amber-500"
							>{formatInterval(card.intervals.hard)}</span
						>
					</button>
					<button
						onclick={() => rate(3)}
						class="flex flex-col items-center justify-center rounded-xl border border-green-200 bg-green-50 py-4 transition-all hover:brightness-95"
					>
						<span class="text-sm font-bold uppercase tracking-tighter text-green-700">Gut</span>
						<span class="mt-1 text-xs text-green-500"
							>{formatInterval(card.intervals.good)}</span
						>
					</button>
					<button
						onclick={() => rate(4)}
						class="flex flex-col items-center justify-center rounded-xl border-2 border-primary bg-white py-4 transition-all hover:bg-primary/5"
					>
						<span class="text-sm font-bold uppercase tracking-tighter text-primary"
							>Einfach</span
						>
						<span class="mt-1 text-xs text-primary/70"
							>{formatInterval(card.intervals.easy)}</span
						>
					</button>
				</div>
				<p
					class="mt-3 text-center text-[10px] font-medium uppercase tracking-wider text-slate-400"
				>
					Tastatur: 1-4
				</p>
			{/if}
		</div>
	</div>
{/if}
