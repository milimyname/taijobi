<script lang="ts">
	import {
		getDueCards,
		getDueCardsFiltered,
		getDueCountFiltered,
		getPacks,
		reviewCard,
		checkAnswer,
		type Card,
		type Pack
	} from '$lib/wasm';
	import { speak } from '$lib/speak';
	import { page } from '$app/state';

	type DrillPhase = 'picking' | 'question' | 'answer' | 'complete';
	type DrillDirection = 'zh-de' | 'de-zh' | 'zh-pinyin';

	let cards: Card[] = $state([]);
	let index = $state(0);
	let phase: DrillPhase = $state('picking');
	let input = $state('');
	let reviewed = $state(0);
	let activeFilter = $state('');
	let filterLabel = $state('');
	let direction: DrillDirection = $state('zh-de');
	let answerCorrect: boolean | null = $state(null);

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
		answerCorrect = null;
	}

	let card = $derived(cards[index] as Card | undefined);
	let total = $derived(cards.length);

	// What to show as the question
	let questionText = $derived.by(() => {
		if (!card) return '';
		if (direction === 'de-zh') return card.translation ?? card.word;
		return card.word;
	});

	// What's the expected answer
	let expectedAnswer = $derived.by(() => {
		if (!card) return '';
		if (direction === 'zh-de') return card.translation ?? '';
		if (direction === 'de-zh') return card.word;
		if (direction === 'zh-pinyin') return card.pinyin ?? '';
		return card.translation ?? '';
	});

	// Is question Chinese (for display sizing)?
	let questionIsChinese = $derived(
		card?.language === 'zh' && (direction as DrillDirection) !== 'de-zh'
	);

	function reveal() {
		if (phase !== 'question') return;
		// Check the answer
		if (input.trim() && expectedAnswer) {
			const lang = direction === 'zh-pinyin' ? 'pinyin' : direction === 'zh-de' ? 'de' : 'zh';
			const result = checkAnswer(input, expectedAnswer, lang);
			answerCorrect = result.correct;
		} else {
			answerCorrect = null;
		}
		phase = 'answer';
	}

	async function rate(rating: number) {
		if (!card) return;
		await reviewCard(card.id, rating);
		reviewed++;
		index++;
		input = '';
		answerCorrect = null;
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

	/** Split Chinese text into individual characters for tappable links */
	function splitChineseChars(text: string): string[] {
		return [...text];
	}

	function isChinese(char: string): boolean {
		const code = char.codePointAt(0) ?? 0;
		return (code >= 0x4E00 && code <= 0x9FFF) ||
			(code >= 0x3400 && code <= 0x4DBF) ||
			(code >= 0x20000 && code <= 0x2A6DF);
	}

	const directions: { id: DrillDirection; label: string }[] = [
		{ id: 'zh-de', label: 'ZH → DE' },
		{ id: 'de-zh', label: 'DE → ZH' },
		{ id: 'zh-pinyin', label: 'ZH → Pinyin' },
	];
</script>

<svelte:window onkeydown={handleKeydown} />

{#if phase === 'picking'}
	<!-- Direction picker -->
	<section class="mt-4">
		<h3 class="mb-2 text-[11px] font-bold uppercase tracking-wider text-primary">Richtung</h3>
		<div class="flex gap-2">
			{#each directions as dir (dir.id)}
				<button
					onclick={() => (direction = dir.id)}
					class="rounded-full px-4 py-1.5 text-sm font-medium transition-colors {direction === dir.id
						? 'bg-primary text-white'
						: 'bg-slate-100 text-slate-600 hover:bg-slate-200'}"
				>
					{dir.label}
				</button>
			{/each}
		</div>
	</section>

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
			{#if questionIsChinese}
				<h1 class="chinese-char mb-2 text-6xl font-bold tracking-tight text-slate-900">
					{questionText}
				</h1>
				{#if direction === 'zh-de' && card.pinyin}
					<div class="flex items-center justify-center gap-3">
						<p class="text-lg font-medium text-primary">{card.pinyin}</p>
						<button
							onclick={() => speak(card.word, card.language)}
							class="flex items-center justify-center rounded-full bg-primary/10 p-2 text-primary transition-colors hover:bg-primary/20"
						>
							<span class="material-symbols-outlined text-xl">volume_up</span>
						</button>
					</div>
				{:else}
					<button
						onclick={() => speak(card.word, card.language)}
						class="mt-2 flex items-center justify-center rounded-full bg-primary/10 p-2 text-primary transition-colors hover:bg-primary/20"
					>
						<span class="material-symbols-outlined text-xl">volume_up</span>
					</button>
				{/if}
			{:else}
				<div class="flex items-center justify-center gap-3">
					<h1 class="text-4xl font-bold tracking-tight text-slate-900">{questionText}</h1>
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
						placeholder="{direction === 'zh-pinyin' ? 'Pinyin eingeben...' : direction === 'de-zh' ? 'Chinesisch eingeben...' : 'Übersetzung eingeben...'}"
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
					class="flex w-full items-stretch overflow-hidden rounded-xl border-2 {answerCorrect === true ? 'border-green-500' : answerCorrect === false ? 'border-red-400' : 'border-primary'} bg-white"
				>
					<div class="flex-1 p-4 text-xl font-semibold {answerCorrect === true ? 'text-green-600' : answerCorrect === false ? 'text-red-600' : 'text-primary'}">
						{expectedAnswer || '—'}
					</div>
					<div class="flex items-center {answerCorrect === true ? 'bg-green-50' : answerCorrect === false ? 'bg-red-50' : 'bg-primary/5'} px-4">
						<span class="material-symbols-outlined text-3xl font-bold {answerCorrect === true ? 'text-green-500' : answerCorrect === false ? 'text-red-500' : 'text-primary'}">
							{answerCorrect === true ? 'check_circle' : answerCorrect === false ? 'cancel' : 'check_circle'}
						</span>
					</div>
				</div>

				{#if input}
					<p class="text-center text-sm {answerCorrect === true ? 'text-green-600' : answerCorrect === false ? 'text-red-500' : 'text-slate-400'}">
						Deine Antwort: <span class="font-medium">{input}</span>
						{#if answerCorrect === true}
							— Richtig!
						{:else if answerCorrect === false}
							— Falsch
						{/if}
					</p>
				{/if}

				<!-- Tappable characters (for Chinese answers) -->
				{#if card.language === 'zh' && direction !== 'zh-pinyin'}
					<div class="flex flex-wrap justify-center gap-1">
						{#each splitChineseChars(card.word) as ch}
							{#if isChinese(ch)}
								<a
									href="/character/{encodeURIComponent(ch)}"
									class="chinese-char rounded-lg bg-primary/5 px-2 py-1 text-xl text-primary transition-colors hover:bg-primary/10"
								>
									{ch}
								</a>
							{:else}
								<span class="px-1 text-xl text-slate-400">{ch}</span>
							{/if}
						{/each}
					</div>
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
