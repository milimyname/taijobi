<script lang="ts">
	import {
		currentAlphabet,
		currentFlashcard,
		currentIndexStore,
		currentLetter,
		innerWidthStore,
		animateSVG,
		showLetterDrawing,
		strokes,
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
		FileText,
		Undo2,
	} from 'lucide-svelte';
	import { clearCanvas, redrawCanvas } from '$lib/utils/actions';
	import BacksideCard from '$lib/components/canvas/BacksideCard.svelte';
	import { cn, getFlashcardWidth, isNonJapanase } from '$lib/utils';
	import { type CarouselAPI } from '$lib/components/ui/carousel/context';
	import CanvasPanel from '$lib/components/canvas/CanvasPanel.svelte';

	export let embla: CarouselAPI;

	const rotateYCard = tweened(0, {
		duration: 2000,
		easing: cubicOut,
	});
	// Get the alphabet store length
	let canvas: HTMLCanvasElement;
	let ctx: CanvasRenderingContext2D;
	let slicedFlashcard: string[];
	let index: number = 0;

	// Get canvas and context
	onMount(() => {
		canvas = document.querySelector('canvas') as HTMLCanvasElement;
		ctx = canvas.getContext('2d') as CanvasRenderingContext2D;

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
		clearCanvas(canvas);
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
		clearCanvas(canvas);
	}

	// Disable the letter drawing if the flashcard is not Japanese
	$: if ($showLetterDrawing && isNonJapanase($currentFlashcard)) $showLetterDrawing = false;
</script>

<div style="perspective: 3000px; position: relative; transform: rotateY(${-$rotateYCard}deg);">
	<span
		class={cn(
			'absolute left-1/2 top-3 z-40 block -translate-x-1/2 text-lg font-medium sm:top-5',
			$rotateYCard > 5 && 'hidden',
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
			$rotateYCard > 5 && $rotateYCard < 175 && 'hidden',
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
			$rotateYCard > 5 && $rotateYCard < 175 && 'hidden',
		)}
		on:click={() => ($rotateYCard < 40 ? rotateYCard.set(180) : rotateYCard.set(0))}
	>
		<RotateCcw class="size-4" />
	</button>

	<BacksideCard rotateYCard={$rotateYCard} />

	<div class={cn($rotateYCard > 5 && 'hidden')}>
		{#if $currentFlashcard.length > 1}
			{#if index === 0}
				<button
					on:click|preventDefault={() => {
						clearCanvas(canvas);

						// Go to the previous flashcard
						$currentIndexStore -= 1;
						$showLetterDrawing = false;
						embla.scrollPrev();
					}}
					class="previousLetter absolute -left-3 top-1/2 z-40 rounded-full border bg-white p-2 shadow-sm transition-all"
				>
					<ChevronFirst class="size-4" />
				</button>
			{:else}
				<button
					on:click|preventDefault={() => {
						index > 0 ? (index -= 1) : null;
						clearCanvas(canvas);
					}}
					class="previousLetter absolute -left-3 top-1/2 z-40 rounded-full border bg-white p-2 shadow-sm transition-all"
				>
					<ArrowLeft class="size-4" />
				</button>
			{/if}

			{#if slicedFlashcard.length - 1 !== index}
				<button
					on:click|preventDefault={() => {
						index < slicedFlashcard.length - 1 ? (index += 1) : null;
						clearCanvas(canvas);
					}}
					class="previousLetter absolute -right-3 top-1/2 z-40 rounded-full border bg-white p-2 shadow-sm transition-all"
				>
					<ArrowRight class="size-4" />
				</button>
			{:else}
				<button
					on:click|preventDefault={() => {
						clearCanvas(canvas);

						// Go to the next flashcard
						$currentIndexStore += 1;
						$showLetterDrawing = false;
						embla.scrollNext();
					}}
					class={cn(
						'previousLetter absolute -right-3 top-1/2 z-40 rounded-full border bg-white p-2 opacity-100 shadow-sm transition-all',
						$currentIndexStore + 1 === embla.scrollSnapList().length &&
							'pointer-events-none opacity-0',
					)}
				>
					<ChevronLast class="size-4" />
				</button>
			{/if}
		{:else}
			<button
				class="previousLetter absolute -right-3 top-1/2 z-40 rounded-full border bg-white p-2 opacity-0 shadow-sm transition-all"
			>
				<ArrowRight class="size-4" />
			</button>

			<button
				on:click|preventDefault={() => {
					clearCanvas(canvas);

					// Go to the next flashcard
					$currentIndexStore += 1;
					$showLetterDrawing = false;
					embla.scrollTo($currentIndexStore);
				}}
				class="previousLetter absolute -right-1 top-1/2 z-40 rounded-full border bg-white p-2 shadow-sm transition-all"
			>
				<ChevronLast class="size-4" />
			</button>
		{/if}
	</div>
</div>

<CanvasPanel {canvas} />
