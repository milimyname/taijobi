<script lang="ts">
	import type { Ctx } from '$lib/utils/ambient.d.ts';
	import {
		currentAlphabet,
		currentFlashcard,
		currentIndexStore,
		currentLetter,
		innerWidthStore,
		animateSVG,
		showLetterDrawing
	} from '$lib/utils/stores';
	import { onMount } from 'svelte';
	import { cubicOut } from 'svelte/easing';
	import { tweened } from 'svelte/motion';
	import Letter from '$lib/components/canvas/Letter.svelte';
	import Canvas from '$lib/components/canvas/Canvas.svelte';
	import { isKanji, isKatakana, isRomaji } from 'wanakana';
	import {
		ArrowLeft,
		ArrowRight,
		RotateCcw,
		RefreshCcw,
		Eraser,
		ChevronLast,
		ChevronFirst,
		FileText
	} from 'lucide-svelte';
	import { clearCanvas } from '$lib/utils/actions';
	import BacksideCard from '$lib/components/canvas/BacksideCard.svelte';
	import Swiper from 'swiper';
	import { getFlashcardWidth, isNonJapanase } from '$lib/utils';

	export let swiperInstance: Swiper;

	const rotateYCard = tweened(0, {
		duration: 2000,
		easing: cubicOut
	});
	// Get the alphabet store length
	let canvas: HTMLCanvasElement;
	let ctx: Ctx;
	let slicedFlashcard: string[];
	let index: number = 0;

	// Get canvas and context
	onMount(() => {
		canvas = document.querySelector('canvas') as HTMLCanvasElement;
		ctx = canvas.getContext('2d') as Ctx;

		$currentLetter = slicedFlashcard[index];
	});

	$: if ($currentFlashcard.length === 1) {
		/// Set the current alphabet if the flashcard contains only one character
		if (isKanji($currentFlashcard)) {
			$currentAlphabet = 'kanji';
		} else if (isKatakana($currentFlashcard)) $currentAlphabet = 'katakana';
		else $currentAlphabet = 'hiragana';

		$currentLetter = $currentFlashcard;

		index = 0;
		clearCanvas(ctx, canvas);
	}

	// Set the current alphabet if the flashcard contains more than one character
	$: if (isKanji(slicedFlashcard[index])) $currentAlphabet = 'kanji';
	else if (isKatakana(slicedFlashcard[index])) $currentAlphabet = 'katakana';
	else $currentAlphabet = 'hiragana';

	$: if ($currentLetter) $currentLetter = slicedFlashcard[index];

	$: {
		slicedFlashcard = $currentFlashcard
			.split('')
			.filter(
				(char) =>
					char !== ' ' &&
					char !== '?' &&
					char !== '。' &&
					char !== '~' &&
					char !== '、' &&
					char !== '-' &&
					isNaN(Number(char)) &&
					!isRomaji(char)
			);
		index = 0;
		clearCanvas(ctx, canvas);
	}

	// Disable the letter drawing if the flashcard is not Japanese
	$: if ($showLetterDrawing && isNonJapanase($currentFlashcard)) $showLetterDrawing = false;
</script>

<div
	style="perspective: 3000px; position: relative; transform: rotateY(${-$rotateYCard}deg); z-index: 100"
>
	<span
		class="{$rotateYCard > 5 ? 'hidden' : 'block'} 
			absolute right-3 top-3 z-40 text-lg font-medium sm:right-5 sm:top-5"
	>
		{#each slicedFlashcard as letter, i}
			<span class={`${i === index ? 'font-medium opacity-100' : 'opacity-50'}`}>
				{letter}
			</span>
		{/each}
	</span>

	<button
		class="{$rotateYCard > 5 && $rotateYCard < 175 ? 'hidden' : 'block'}
		absolute bottom-3 left-2 z-40 rounded-full border bg-white p-2 shadow-sm transition-all sm:bottom-5 sm:left-5"
		on:click={() => ($showLetterDrawing = false)}
	>
		<FileText class="h-4 w-4" />
	</button>

	<Canvas rotationY={$rotateYCard} {canvas} {ctx} />

	<Letter rotationY={$rotateYCard} />

	<button
		class="{$rotateYCard > 5 && $rotateYCard < 175 ? 'hidden' : 'block'}
				absolute bottom-3 right-2 z-40 rounded-full border bg-white p-2 shadow-sm transition-all sm:bottom-5 sm:right-5"
		on:click={() => ($rotateYCard < 40 ? rotateYCard.set(180) : rotateYCard.set(0))}
	>
		<RotateCcw class="h-4 w-4" />
	</button>

	<BacksideCard rotateYCard={$rotateYCard} />
</div>

<div
	style={`width: ${getFlashcardWidth($innerWidthStore)}px;`}
	class="z-40 mt-5 flex items-center justify-between sm:mx-auto"
>
	{#if $currentFlashcard.length > 1}
		{#if index === 0}
			<button
				on:click|preventDefault={() => {
					clearCanvas(ctx, canvas);

					// Go to the previous flashcard
					$currentIndexStore -= 1;
					$showLetterDrawing = false;
					swiperInstance.slideTo($currentIndexStore);
				}}
				class="previousLetter h-fit w-fit rounded-full border bg-white p-2 shadow-sm transition-all"
			>
				<ChevronFirst class="h-4 w-4" />
			</button>
		{:else}
			<button
				on:click|preventDefault={() => {
					index > 0 ? (index -= 1) : null;
					clearCanvas(ctx, canvas);
				}}
				class="previousLetter h-fit w-fit rounded-full border bg-white p-2 shadow-sm transition-all"
			>
				<ArrowLeft class="h-4 w-4" />
			</button>
		{/if}

		<div class="flex items-center justify-center">
			<div
				class="flex items-center justify-between gap-8 rounded-full bg-black px-4 py-2 text-white"
			>
				<button on:click|preventDefault={() => clearCanvas(ctx, canvas)}>
					<Eraser class="h-4 w-4 " />
				</button>
				<button
					on:click|preventDefault={() => {
						$animateSVG = !$animateSVG;
						// setTimeout(() => ($animateSVG = true), 250);
					}}
					class="transition-transform active:rotate-180"
				>
					<RefreshCcw class="h-4 w-4" />
				</button>
			</div>
		</div>

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

					// Go to the next flashcard
					$currentIndexStore += 1;
					$showLetterDrawing = false;
					swiperInstance.slideTo($currentIndexStore);
				}}
				class="previousLetter h-fit w-fit rounded-full border bg-white p-2 shadow-sm transition-all
				{$currentIndexStore + 1 === swiperInstance.slides.length
					? 'pointer-events-none opacity-0'
					: 'opacity-100'}"
			>
				<ChevronLast class="h-4 w-4" />
			</button>
		{/if}
	{:else}
		<button
			class="previousLetter h-fit w-fit rounded-full border bg-white p-2 opacity-0 shadow-sm transition-all"
		>
			<ArrowRight class="h-4 w-4" />
		</button>
		<div class="flex items-center justify-center">
			<div
				class="flex items-center justify-between gap-8 rounded-full bg-black px-4 py-2 text-white"
			>
				<button on:click|preventDefault={() => clearCanvas(ctx, canvas)}>
					<Eraser class="h-4 w-4 " />
				</button>
				<button
					on:click|preventDefault={() => {
						$animateSVG = !$animateSVG;
						// setTimeout(() => ($animateSVG = true), 250);
					}}
					class="transition-transform active:rotate-180"
				>
					<RefreshCcw class="h-4 w-4" />
				</button>
			</div>
		</div>

		<button
			on:click|preventDefault={() => {
				clearCanvas(ctx, canvas);

				// Go to the next flashcard
				$currentIndexStore += 1;
				$showLetterDrawing = false;
				swiperInstance.slideTo($currentIndexStore);
			}}
			class="previousLetter h-fit w-fit rounded-full border bg-white p-2 shadow-sm transition-all"
		>
			<ChevronLast class="h-4 w-4" />
		</button>
	{/if}
</div>
