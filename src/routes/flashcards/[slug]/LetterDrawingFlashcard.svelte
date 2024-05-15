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
	import { cn, getFlashcardWidth, isNonJapanase } from '$lib/utils';
	import { type CarouselAPI } from '$lib/components/ui/carousel/context';

	export let embla: CarouselAPI;

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
		// Set the current alphabet if the flashcard contains only one character
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
			.filter((char) => !/[ ?。~、\-0-9]/.test(char) && !isRomaji(char));
		index = 0;
		clearCanvas(ctx, canvas);
	}

	// Disable the letter drawing if the flashcard is not Japanese
	$: if ($showLetterDrawing && isNonJapanase($currentFlashcard)) $showLetterDrawing = false;
</script>

<div style="perspective: 3000px; position: relative; transform: rotateY(${-$rotateYCard}deg);">
	<span
		class={cn(
			'absolute right-3 top-3 z-40 block text-lg font-medium sm:right-5 sm:top-5',
			$rotateYCard > 5 && 'hidden'
		)}
	>
		{#each slicedFlashcard as letter, i}
			<span class={cn('opacity-50', i === index && 'font-medium opacity-100')}>
				{letter}
			</span>
		{/each}
	</span>

	<button
		class={cn(
			'absolute bottom-3 left-3 z-40 block rounded-full border bg-white p-2 shadow-sm transition-all xm:bottom-5 xm:left-5',
			$rotateYCard > 5 && $rotateYCard < 175 && 'hidden'
		)}
		on:click={() => ($showLetterDrawing = false)}
	>
		<FileText class="size-4" />
	</button>

	<Canvas rotationY={$rotateYCard} {canvas} />

	<Letter rotationY={$rotateYCard} />

	<button
		class={cn(
			'absolute bottom-3 right-2 z-40 block rounded-full border bg-white p-2 shadow-sm transition-all xm:bottom-5 xm:right-5',
			$rotateYCard > 5 && $rotateYCard < 175 && 'hidden'
		)}
		on:click={() => ($rotateYCard < 40 ? rotateYCard.set(180) : rotateYCard.set(0))}
	>
		<RotateCcw class="size-4" />
	</button>

	<BacksideCard rotateYCard={$rotateYCard} />
</div>

<div
	style={`width: ${getFlashcardWidth($innerWidthStore)}px;`}
	class="my-5 flex items-center justify-between sm:mx-auto lg:-order-1 lg:my-0"
>
	{#if $currentFlashcard.length > 1}
		{#if index === 0}
			<button
				on:click|preventDefault={() => {
					clearCanvas(ctx, canvas);

					// Go to the previous flashcard
					$currentIndexStore -= 1;
					$showLetterDrawing = false;
					embla.scrollPrev();
				}}
				class="previousLetter rounded-full border bg-white p-2 shadow-sm transition-all"
			>
				<ChevronFirst class="size-4" />
			</button>
		{:else}
			<button
				on:click|preventDefault={() => {
					index > 0 ? (index -= 1) : null;
					clearCanvas(ctx, canvas);
				}}
				class="previousLetter rounded-full border bg-white p-2 shadow-sm transition-all"
			>
				<ArrowLeft class="size-4" />
			</button>
		{/if}

		<div class="flex items-center justify-between gap-8 rounded-full bg-black px-4 py-2 text-white">
			<button on:click|preventDefault={() => clearCanvas(ctx, canvas)}>
				<Eraser class="size-4" />
			</button>
			<button
				on:click|preventDefault={() => {
					$animateSVG = !$animateSVG;
					// setTimeout(() => ($animateSVG = true), 250);
				}}
				class="transition-transform active:rotate-180"
			>
				<RefreshCcw class="size-4" />
			</button>
		</div>

		{#if slicedFlashcard.length - 1 !== index}
			<button
				on:click|preventDefault={() => {
					index < slicedFlashcard.length - 1 ? (index += 1) : null;
					clearCanvas(ctx, canvas);
				}}
				class="previousLetter rounded-full border bg-white p-2 shadow-sm transition-all"
			>
				<ArrowRight class="size-4" />
			</button>
		{:else}
			<button
				on:click|preventDefault={() => {
					clearCanvas(ctx, canvas);

					// Go to the next flashcard
					$currentIndexStore += 1;
					$showLetterDrawing = false;
					embla.scrollNext();
				}}
				class={cn(
					'previousLetter rounded-full border bg-white p-2 opacity-100 shadow-sm transition-all',
					$currentIndexStore + 1 === embla.scrollSnapList().length &&
						'pointer-events-none opacity-0'
				)}
			>
				<ChevronLast class="size-4" />
			</button>
		{/if}
	{:else}
		<button
			class="previousLetter rounded-full border bg-white p-2 opacity-0 shadow-sm transition-all"
		>
			<ArrowRight class="size-4" />
		</button>
		<div class="flex items-center justify-center">
			<div
				class="flex items-center justify-between gap-8 rounded-full bg-black px-4 py-2 text-white"
			>
				<button on:click|preventDefault={() => clearCanvas(ctx, canvas)}>
					<Eraser class="size-4" />
				</button>
				<button
					on:click|preventDefault={() => {
						$animateSVG = !$animateSVG;
						// setTimeout(() => ($animateSVG = true), 250);
					}}
					class="transition-transform active:rotate-180"
				>
					<RefreshCcw class="size-4" />
				</button>
			</div>
		</div>

		<button
			on:click|preventDefault={() => {
				clearCanvas(ctx, canvas);

				// Go to the next flashcard
				$currentIndexStore += 1;
				$showLetterDrawing = false;
				embla.scrollTo($currentIndexStore);
			}}
			class="previousLetter rounded-full border bg-white p-2 shadow-sm transition-all"
		>
			<ChevronLast class="size-4" />
		</button>
	{/if}
</div>
