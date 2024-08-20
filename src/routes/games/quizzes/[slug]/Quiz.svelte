<script lang="ts">
	import { goto } from '$app/navigation';
	import { page } from '$app/stores';
	import { cn, getFlashcardWidth, getFlashcardHeight } from '$lib/utils';
	import {
		innerWidthStore,
		innerHeightStore,
		searchKanji,
		searchedWordStore,
	} from '$lib/utils/stores';
	import { ChevronRight } from 'lucide-svelte';
	import { tweened } from 'svelte/motion';

	export let flashcard: {
		meaning: string;
		name: string;
	};
	export let shuffledOptions: string[];
	export let selectAnswer: (e: any, name: string) => void;
	export let ratio: number;
	export let type: string;
	export let timeLeft: number | undefined;
	export let duration: number;
	export let nextQuestion: () => void;
	export let flashcardBox: string;

	let tweenedRatio = tweened(0);

	function handleNavigation() {
		let callback = encodeURIComponent($page.url.pathname);
		if ('onyomi' in flashcard || 'kunyomi' in flashcard) {
			$searchKanji = flashcard.name;
			goto(`/alphabets/kanji?callback=${callback}`);
		} else {
			$searchedWordStore = { name: flashcard.name, meaning: flashcard.meaning };
			goto(`/flashcards/${flashcardBox}?callback=${callback}`);
		}
	}

	$: clicked = false;

	$: $tweenedRatio = ratio;
</script>

<section class="mb-5 flex h-full flex-col items-center justify-center gap-4 sm:gap-5">
	<div
		style={`height: ${getFlashcardHeight($innerWidthStore, $innerHeightStore)}px;
			width: ${getFlashcardWidth($innerWidthStore)}px`}
		class="relative my-auto flex items-center justify-center overflow-hidden rounded-xl border p-10 shadow-sm lg:my-0"
	>
		<div
			class="absolute left-0 top-0 h-2 rounded-b-xl rounded-l-xl bg-primary"
			style={`width: ${((timeLeft ?? 0) / duration) * 100}%;`}
		/>
		{#if type === 'name'}
			<h2 class={flashcard?.meaning.length > 2 ? 'text-2xl sm:text-4xl' : 'text-5xl sm:text-8xl'}>
				{flashcard?.meaning ?? shuffledOptions[0]}
			</h2>
		{:else}
			<h2 class={flashcard?.name.length > 2 ? 'text-3xl sm:text-4xl' : 'text-4xl  sm:text-8xl'}>
				{flashcard?.name ?? shuffledOptions[0]}
			</h2>
		{/if}

		<div
			class="absolute bottom-0 left-0 h-2 rounded-l-xl rounded-t-xl bg-black"
			style={`width: ${$tweenedRatio * 100}%`}
		/>

		{#if timeLeft === 0}
			<button
				class="flx absolute bottom-3 left-1/2 z-30 w-fit -translate-x-1/2 gap-2 rounded-full border bg-white p-2 px-4 shadow-sm transition-all xm:bottom-5 xm:right-5"
				on:click={handleNavigation}
			>
				<div class="shrink-0">See it</div>
			</button>

			<button
				class="absolute bottom-3 right-2 z-30 rounded-full border bg-white p-2 shadow-sm transition-all xm:bottom-5 xm:right-5"
				on:click={nextQuestion}
			>
				<ChevronRight class="size-4" />
			</button>
		{/if}
	</div>
	<div
		style={`width: ${getFlashcardWidth($innerWidthStore)}px;`}
		class={cn(
			'grid grid-cols-2 justify-center gap-2 text-sm sm:gap-5 sm:text-lg',
			type === 'name' && 'text-xl sm:text-4xl',
		)}
	>
		{#each shuffledOptions as option}
			<button
				disabled={clicked}
				class="quiz-btn w-full justify-self-center rounded-xl border-2 border-black bg-white p-2 disabled:cursor-not-allowed sm:p-4"
				on:click|preventDefault={(e) => {
					clicked = true;
					selectAnswer(e, option);

					setTimeout(() => {
						clicked = false;
					}, 1000);
				}}
			>
				{option}
			</button>
		{/each}
	</div>
</section>
