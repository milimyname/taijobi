<script lang="ts">
	import type { Ctx } from '$lib/utils/ambient.d.ts';
	import {
		currentAlphabet,
		currentFlashcard,
		currentIndexStore,
		currentLetter
	} from '$lib/utils/stores';
	import { onMount } from 'svelte';
	import { cubicOut } from 'svelte/easing';
	import { tweened } from 'svelte/motion';
	import Letter from '$lib/components/canvas/Letter.svelte';
	import Canvas from '$lib/components/canvas/Canvas.svelte';
	import MobileNav from '$lib/components/MobileNav.svelte';
	import { page } from '$app/stores';
	import { isKanji, isKatakana } from 'wanakana';
	import { ArrowLeft, ArrowRight } from 'lucide-svelte';

	const rotateYCard = tweened(0, {
		duration: 2000,
		easing: cubicOut
	});
	// Get the alphabet store length
	let canvas: HTMLCanvasElement;
	let ctx: Ctx;
	let slicedFlashcard: string[] = $currentFlashcard.split('').filter((char) => char !== ' ');
	let index: number = 0;

	// Get canvas and context
	onMount(() => {
		canvas = document.querySelector('canvas') as HTMLCanvasElement;
		ctx = canvas.getContext('2d') as Ctx;

		$currentLetter = slicedFlashcard[index];

		$currentIndexStore = +($page.url.pathname?.split('-').at(-1) ?? 0);
	});

	$: if ($currentFlashcard.length === 1) {
		/// Set the current alphabet if the flashcard contains only one character
		if (isKanji($currentFlashcard)) {
			$currentAlphabet = 'kanji';
			console.log(isKanji($currentFlashcard), $currentFlashcard, $currentLetter);
		} else if (isKatakana($currentFlashcard)) $currentAlphabet = 'katakana';
		else $currentAlphabet = 'hiragana';

		$currentLetter = $currentFlashcard;
	}

	// Set the current alphabet if the flashcard contains more than one character
	$: if ($currentFlashcard.length > 1) {
		if (isKanji(slicedFlashcard[index])) $currentAlphabet = 'kanji';
		else if (isKatakana(slicedFlashcard[index])) $currentAlphabet = 'katakana';
		else $currentAlphabet = 'hiragana';

		$currentLetter = slicedFlashcard[index];

	}
</script>

<section class="mb-24 flex flex-1 flex-col justify-center gap-2 sm:justify-center sm:gap-5">
	<div class="relative">
		<Canvas rotationY={$rotateYCard} {canvas} {ctx} />
		<Letter rotationY={$rotateYCard} />

		<span class="absolute right-3 top-3 z-30 text-lg font-medium sm:right-5 sm:top-5">
			{#each slicedFlashcard as letter, i}
				<span class={`${i === index ? 'font-bold opacity-100' : 'opacity-50'}`}>
					{letter}
				</span>
			{/each}
		</span>

		{#if $currentFlashcard.length > 1}
			<div class="mt-5 flex items-center justify-between sm:mx-auto">
				<button
					on:click|preventDefault={() => (index > 0 ? (index -= 1) : null)}
					class="previousLetter h-fit w-fit rounded-full border bg-white p-2 shadow-sm transition-all"
				>
					<ArrowLeft class="h-4 w-4" />
				</button>

				<button
					on:click|preventDefault={() => (index < slicedFlashcard.length - 1 ? (index += 1) : null)}
					class="previousLetter h-fit w-fit rounded-full border bg-white p-2 shadow-sm transition-all"
				>
					<ArrowRight class="h-4 w-4" />
				</button>
			</div>
		{/if}
	</div>

	<MobileNav />
</section>
