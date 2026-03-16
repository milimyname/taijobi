<script lang="ts">
	import { getDueCards, reviewCard, type Card } from '$lib/wasm';

	type DrillPhase = 'question' | 'answer' | 'complete';

	let cards: Card[] = $state([]);
	let index = $state(0);
	let phase: DrillPhase = $state('question');
	let input = $state('');
	let reviewed = $state(0);

	function load() {
		cards = getDueCards(50);
		index = 0;
		phase = cards.length > 0 ? 'question' : 'complete';
		input = '';
		reviewed = 0;
	}

	load();

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

{#if phase === 'complete'}
	<div class="flex flex-col items-center pt-20">
		<div
			class="flex size-16 items-center justify-center rounded-full bg-primary-light text-primary"
		>
			<span class="material-symbols-outlined text-[32px]">check_circle</span>
		</div>
		<p class="mt-4 text-2xl font-bold text-stone-900">Session Complete</p>
		<p class="mt-2 text-sm text-stone-500">{reviewed} cards reviewed</p>
		<a
			href="/"
			class="mt-8 rounded-lg bg-primary px-8 py-3 font-semibold text-white shadow-md shadow-primary/20 transition-all hover:bg-primary/90"
		>
			Back to Dashboard
		</a>
	</div>
{:else if card}
	<!-- Progress -->
	<div class="mb-6 mt-4 flex items-center gap-3">
		<div class="h-2 flex-1 overflow-hidden rounded-full bg-stone-200/50">
			<div
				class="h-full rounded-full bg-primary transition-all"
				style="width: {((index) / total) * 100}%"
			></div>
		</div>
		<span class="text-[11px] font-bold text-stone-400">{index + 1}/{total}</span>
	</div>

	<!-- Card -->
	<div
		class="flex flex-col items-center rounded-xl border border-border-subtle bg-white p-8 shadow-sm"
	>
		<p class="chinese-char text-6xl font-light text-stone-900">{card.word}</p>
		{#if card.pinyin}
			<p class="mt-3 text-lg text-stone-400">{card.pinyin}</p>
		{/if}

		{#if phase === 'question'}
			<input
				type="text"
				bind:value={input}
				placeholder="Translation..."
				class="mt-8 w-full rounded-lg border border-border-subtle bg-surface px-4 py-3 text-center text-stone-900 placeholder-stone-400 outline-none focus:border-primary"
			/>
			<button
				onclick={reveal}
				class="mt-4 w-full rounded-lg border border-border-subtle bg-stone-50 py-3 font-medium text-stone-600 transition-colors hover:bg-stone-100"
			>
				Show Answer
			</button>
		{:else}
			<!-- Answer revealed -->
			<div class="mt-8 w-full rounded-lg border border-border-subtle bg-surface px-6 py-4 text-center">
				<p class="text-lg font-semibold text-stone-900">{card.translation ?? '—'}</p>
				{#if input}
					<p class="mt-2 text-sm text-stone-400">You typed: {input}</p>
				{/if}
			</div>

			<!-- Rating buttons -->
			<div class="mt-6 grid w-full grid-cols-4 gap-2">
				<button
					onclick={() => rate(1)}
					class="flex flex-col items-center rounded-lg border border-red-200 bg-red-50 py-3 text-red-700 transition-colors hover:bg-red-100"
				>
					<span class="text-sm font-semibold">Again</span>
					<span class="text-[10px] font-bold text-red-400">{formatInterval(card.intervals.again)}</span>
				</button>
				<button
					onclick={() => rate(2)}
					class="flex flex-col items-center rounded-lg border border-orange-200 bg-orange-50 py-3 text-orange-700 transition-colors hover:bg-orange-100"
				>
					<span class="text-sm font-semibold">Hard</span>
					<span class="text-[10px] font-bold text-orange-400"
						>{formatInterval(card.intervals.hard)}</span
					>
				</button>
				<button
					onclick={() => rate(3)}
					class="flex flex-col items-center rounded-lg border border-primary/20 bg-primary-light/50 py-3 text-primary transition-colors hover:bg-primary-light"
				>
					<span class="text-sm font-semibold">Good</span>
					<span class="text-[10px] font-bold text-accent"
						>{formatInterval(card.intervals.good)}</span
					>
				</button>
				<button
					onclick={() => rate(4)}
					class="flex flex-col items-center rounded-lg border border-blue-200 bg-blue-50 py-3 text-blue-700 transition-colors hover:bg-blue-100"
				>
					<span class="text-sm font-semibold">Easy</span>
					<span class="text-[10px] font-bold text-blue-400"
						>{formatInterval(card.intervals.easy)}</span
					>
				</button>
			</div>
			<p class="mt-3 text-center text-[10px] font-medium uppercase tracking-wider text-stone-400">
				Keyboard: 1-4
			</p>
		{/if}
	</div>
{/if}
