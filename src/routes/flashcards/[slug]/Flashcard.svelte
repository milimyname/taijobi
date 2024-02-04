<script lang="ts">
	import type { FlashcardType } from '$lib/utils/ambient.d.ts';
	import { kanji } from '$lib/static/kanji';
	import { fly } from 'svelte/transition';
	import {
		currentAlphabet,
		currentFlashcard,
		showLetterDrawing,
		showProgressSlider,
		innerHeightStore,
		innerWidthStore,
		currentFlashcardTypeStore
	} from '$lib/utils/stores';
	import { quintOut, cubicOut } from 'svelte/easing';
	import { tweened } from 'svelte/motion';
	import { RotateCcw, Scroll, PenTool } from 'lucide-svelte';
	import { getFlashcardHeight, getFlashcardWidth } from '$lib/utils';

	const rotateYCard = tweened(0, {
		duration: 2000,
		easing: cubicOut
	});

	let showNotes: boolean = false;

	export let wordFlashcard: FlashcardType;
	export let currentFlashcardFurigana: string;
	export let currentIndex: number;
	export let longWord: boolean;

	$: kanjiFlashcard = kanji[$currentFlashcard as keyof typeof kanji];
</script>

<div style="perspective: 3000px; position: relative;">
	<div
		style={`transform: rotateY(${-$rotateYCard}deg); transform-style: preserve-3d; backface-visibility: hidden; 
				height: ${getFlashcardHeight($innerWidthStore, $innerHeightStore)}px;
				width: ${getFlashcardWidth($innerWidthStore)}px `}
		class="relative z-10 cursor-pointer
				{$rotateYCard > 90 ? 'hidden' : 'block'}  rounded-xl
				{longWord && 'py-10 sm:py-32'} flex items-center justify-center border
				shadow-sm bg-dotted-spacing-8 bg-dotted-gray-200"
	>
		{#if $currentFlashcardTypeStore === 'kanji'}
			<span class="text-9xl sm:text-[14rem]">
				{$currentFlashcard}
			</span>
		{:else if $currentFlashcardTypeStore === 'phrase'}
			<p class="text-balance px-10 text-center text-5xl leading-normal tracking-widest">
				{@html currentFlashcardFurigana}
			</p>
		{:else}
			<p class="vertical text-balance text-5xl leading-normal tracking-widest">
				{@html currentFlashcardFurigana}
			</p>
		{/if}

		<span class="fixed left-2 top-3 z-30 text-sm xm:left-5 xm:top-5">
			{currentIndex + 1}
		</span>

		<button
			class="absolute bottom-3 left-2 z-30 rounded-full border bg-white p-2 shadow-sm transition-all xm:bottom-5 xm:left-5
				{showNotes && 'hidden'}"
			on:click={() => {
				$showLetterDrawing = true;
				$showProgressSlider = false;
			}}
		>
			<PenTool class="h-4 w-4" />
		</button>

		<button
			class="{showNotes && 'hidden'} 
						absolute bottom-3 right-2 z-30 rounded-full border bg-white p-2 shadow-sm transition-all xm:bottom-5 xm:right-5"
			on:click={() => ($rotateYCard < 40 ? rotateYCard.set(180) : rotateYCard.set(0))}
		>
			<RotateCcw class="h-4 w-4" />
		</button>
	</div>

	<div
		style={`transform: rotateY(${180 - $rotateYCard}deg); backface-visibility: hidden; 
				height: ${getFlashcardHeight($innerWidthStore, $innerHeightStore)}px;
				width: ${getFlashcardWidth($innerWidthStore)}px`}
		class="relative z-10 mx-auto
				{$rotateYCard > 90 ? 'block' : 'hidden'} 
				 flex flex-col
				 {$currentAlphabet === 'kanji' ? 'gap-1' : 'gap-5'}  
				justify-center overflow-hidden rounded-xl border p-5 shadow-sm sm:p-10"
	>
		{#if $currentFlashcardTypeStore === 'kanji'}
			<div
				class="grid-rows-[max-content max-content] sm:grid-rows-[max-content 1fr] grid h-full grid-cols-2 sm:gap-4"
			>
				<h2 class="col-span-2 text-center text-6xl sm:text-9xl">{$currentFlashcard}</h2>

				<h2 class="text-lg font-medium">{kanjiFlashcard.meaning}</h2>

				{#if kanjiFlashcard.onyomi.length > 0}
					<div>
						<h4 class="text-lg tracking-widest">{kanjiFlashcard.onyomi}</h4>
						<p class="text-sm text-gray-300">Onyomi</p>
					</div>
				{/if}

				{#if kanjiFlashcard.kunyomi.length > 0}
					<div>
						<h4 class="text-lg tracking-widest">{kanjiFlashcard.kunyomi}</h4>
						<p class=" text-sm text-gray-300">Kunyomi</p>
					</div>
				{/if}
				{#if wordFlashcard.notes && wordFlashcard.notes.length > 0}
					<button
						class="fixed bottom-0 left-0 z-10 rounded-tr-xl {showNotes
							? 'bg-white text-black'
							: 'bg-blue-200'} p-5"
						on:click|preventDefault={() => (showNotes = !showNotes)}
					>
						<Scroll class="h-6 w-6" />
					</button>

					{#if showNotes}
						<p
							transition:fly={{
								delay: 0,
								duration: 1000,
								opacity: 0,
								y: 400,
								easing: quintOut
							}}
							class="z-4 absolute bottom-0 left-0 h-5/6 w-full rounded-xl bg-primary p-4 text-sm text-white"
						>
							{wordFlashcard.notes}
						</p>
					{/if}
				{/if}
				<button
					class="{showNotes && 'hidden'}
								fixed bottom-5 right-5 z-30 rounded-full border bg-white p-2 shadow-sm transition-all"
					on:click={() => ($rotateYCard < 40 ? rotateYCard.set(180) : rotateYCard.set(0))}
				>
					<RotateCcw class="h-4 w-4" />
				</button>
			</div>
		{:else}
			<div
				class="grid-rows-[max-content max-content] sm:grid-rows-[max-content 1fr] grid h-full grid-cols-2 sm:gap-4"
			>
				<h2 class="col-span-2 text-center text-4xl">{$currentFlashcard}</h2>
				<div>
					<h2 class="text-xl font-medium">
						{wordFlashcard && wordFlashcard.meaning}
					</h2>
					<p class=" text-sm text-gray-300">Meaning</p>
				</div>
				{#if wordFlashcard.customFurigana}
					<div>
						<h2 class="text-xl font-medium">{wordFlashcard.customFurigana}</h2>
						<p class=" text-sm text-gray-300">Custom furigana</p>
					</div>
				{/if}
				{#if wordFlashcard.romanji}
					<div>
						<h2 class="text-xl font-medium">{wordFlashcard.romanji}</h2>
						<p class=" text-sm text-gray-300">Romanji/Furigana</p>
					</div>
				{/if}
				{#if wordFlashcard.notes && wordFlashcard.notes.length > 0}
					<button
						class="fixed bottom-0 left-0 z-10 rounded-tr-xl {showNotes
							? 'bg-white text-black'
							: 'bg-blue-200'} p-5"
						on:click|preventDefault={() => (showNotes = !showNotes)}
					>
						<Scroll class="h-6 w-6" />
					</button>

					{#if showNotes}
						<p
							transition:fly={{
								delay: 0,
								duration: 1000,
								opacity: 0,
								y: 400,
								easing: quintOut
							}}
							class="z-4 absolute bottom-0 left-0 h-5/6 w-full rounded-xl bg-primary p-4 text-xl text-white"
						>
							{wordFlashcard.notes}
						</p>
					{/if}
				{/if}

				<button
					class="{showNotes && 'hidden'}
								fixed bottom-5 right-5 z-30 rounded-full border bg-white p-2 shadow-sm transition-all"
					on:click={() => ($rotateYCard < 40 ? rotateYCard.set(180) : rotateYCard.set(0))}
				>
					<RotateCcw class="h-4 w-4" />
				</button>
			</div>
		{/if}
	</div>
</div>

<style>
	.vertical {
		-webkit-writing-mode: vertical-rl;
		-moz-writing-mode: vertical-rl;
		-ms-writing-mode: vertical-rl;
		writing-mode: vertical-rl;
	}
</style>
