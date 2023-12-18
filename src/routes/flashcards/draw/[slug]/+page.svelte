<script lang="ts">
	import type { Ctx } from '$lib/utils/ambient.d.ts';
	import {
		currentAlphabet,
		currentFlashcard,
		currentIndexStore,
		currentLetter,
		innerWidthStore
	} from '$lib/utils/stores';
	import { onMount } from 'svelte';
	import { cubicOut } from 'svelte/easing';
	import { tweened } from 'svelte/motion';
	import Letter from '$lib/components/canvas/Letter.svelte';
	import Canvas from '$lib/components/canvas/Canvas.svelte';
	import MobileNav from '$lib/components/MobileNav.svelte';
	import { page } from '$app/stores';
	import { isKanji, isKatakana } from 'wanakana';
	import { ArrowLeft, ArrowRight, RotateCcw } from 'lucide-svelte';
	import { clearCanvas } from '$lib/utils/actions';
	import BacksideCard from '$lib/components/canvas/BacksideCard.svelte';
	import { twSmallScreen, xmSmallScreen, canvasLgWidth, canvasSmWidth } from '$lib/utils/constants';
	import { getLocalStorageItem } from '$lib/utils/localStorage';

	const rotateYCard = tweened(0, {
		duration: 2000,
		easing: cubicOut
	});
	// Get the alphabet store length
	let canvas: HTMLCanvasElement;
	let ctx: Ctx;
	let slicedFlashcard: string[];
	let index: number = 0;

	let localStorageFlashcard = getLocalStorageItem('currentFlashcard');

	if (localStorageFlashcard) {
		$currentFlashcard = localStorageFlashcard;
		slicedFlashcard = localStorageFlashcard.split('').filter((char) => char !== ' ');
	} else if ($currentFlashcard)
		slicedFlashcard = $currentFlashcard.split('').filter((char) => char !== ' ');

	// Get canvas and context
	onMount(() => {
		canvas = document.querySelector('canvas') as HTMLCanvasElement;
		ctx = canvas.getContext('2d') as Ctx;

		// Set the current flashcard to the one in localStorage
		localStorage.setItem('currentFlashcard', $currentFlashcard);

		$currentLetter = slicedFlashcard[index];

		$currentIndexStore = +($page.url.pathname?.split('-').at(-1) ?? 0);
	});

	$: if ($currentFlashcard.length === 1) {
		/// Set the current alphabet if the flashcard contains only one character
		if (isKanji($currentFlashcard)) {
			$currentAlphabet = 'kanji';
		} else if (isKatakana($currentFlashcard)) $currentAlphabet = 'katakana';
		else $currentAlphabet = 'hiragana';

		$currentLetter = $currentFlashcard;
	}

	// Set the current alphabet if the flashcard contains more than one character
	$: {
		if (isKanji(slicedFlashcard[index])) $currentAlphabet = 'kanji';
		else if (isKatakana(slicedFlashcard[index])) $currentAlphabet = 'katakana';
		else $currentAlphabet = 'hiragana';
		$currentLetter = slicedFlashcard[index];
	}
</script>

<section class="mb-24 flex flex-1 flex-col justify-center gap-2 sm:justify-center sm:gap-5">
	<div style="perspective: 3000px; position: relative; overflow: hidden;">
		<div>
			<span
				class="{$rotateYCard > 5 ? 'hidden' : 'block'} 
			absolute right-3 top-3 z-30 text-lg font-medium sm:right-5 sm:top-5"
			>
				{#each slicedFlashcard as letter, i}
					<span class={`${i === index ? 'font-medium opacity-100' : 'opacity-50'}`}>
						{letter}
					</span>
				{/each}
			</span>

			<Canvas rotationY={$rotateYCard} {canvas} {ctx} />

			<Letter rotationY={$rotateYCard} />

			<button
				class="{$rotateYCard > 5 && $rotateYCard < 175 ? 'hidden' : 'block'}
				absolute bottom-3 right-2 z-30 rounded-full border bg-white p-2 shadow-sm transition-all sm:bottom-5 sm:right-5"
				on:click={() => ($rotateYCard < 40 ? rotateYCard.set(180) : rotateYCard.set(0))}
			>
				<RotateCcw class="h-4 w-4" />
			</button>

			<BacksideCard rotateYCard={$rotateYCard} />
		</div>
	</div>

	{#if $currentFlashcard.length > 1}
		<div
			style={`width: ${
				$innerWidthStore > twSmallScreen
					? canvasLgWidth
					: $innerWidthStore < xmSmallScreen
						? canvasSmWidth
						: $innerWidthStore * 0.9
			}px;`}
			class="mt-5 flex items-center justify-between sm:mx-auto"
		>
			<button
				on:click|preventDefault={() => {
					index > 0 ? (index -= 1) : null;
					clearCanvas(ctx, canvas);
				}}
				class="previousLetter h-fit w-fit rounded-full border bg-white p-2 shadow-sm transition-all"
			>
				<ArrowLeft class="h-4 w-4" />
			</button>

			{#if slicedFlashcard.length - 1 !== index}
				<button
					on:click|preventDefault={() => {
						index < slicedFlashcard.length - 1 ? (index += 1) : null;
						clearCanvas(ctx, canvas);
					}}
					class="previousLetter h-fit w-fit rounded-full border bg-white p-2 shadow-sm transition-all"
				>
					<ArrowRight class="h-4 w-4" />
				</button>
			{:else}
				<button
					on:click|preventDefault={() => {
						clearCanvas(ctx, canvas);
						index = 0;
					}}
					class="previousLetter h-fit w-fit rounded-full border bg-white px-3 py-1 shadow-sm transition-all"
				>
					1
				</button>
			{/if}
		</div>
	{/if}
	<MobileNav />
</section>
