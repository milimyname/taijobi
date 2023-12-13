<script lang="ts">
	import type { FlashcardType } from '$lib/utils/ambient.d.ts';
	import { kanji } from '$lib/static/kanji';
	import { fly } from 'svelte/transition';
	import { currentAlphabet, currentFlashcard } from '$lib/utils/stores';
	import { quintOut, cubicOut } from 'svelte/easing';
	import { tweened } from 'svelte/motion';
	import { RotateCcw, Scroll, PenTool } from 'lucide-svelte';
	import { goto } from '$app/navigation';
	import { page } from '$app/stores';

	const rotateYCard = tweened(0, {
		duration: 2000,
		easing: cubicOut
	});

	let showNotes: boolean = false;

	export let flashcards: FlashcardType[];
	export let currentFlashcardFurigana: string;
	export let currentFlashcardType: string;
	export let currentIndex: number;
	export let longWord: boolean;

	let flashcard = kanji[$currentFlashcard as keyof typeof kanji];
</script>

<div style="perspective: 3000px; position: relative;">
	<div
		style={`transform: rotateY(${-$rotateYCard}deg); transform-style: preserve-3d; backface-visibility: hidden; `}
		class="relative z-10 cursor-pointer
				{$rotateYCard > 90 ? 'hidden' : 'block'} h-[60dvh] w-[300px] rounded-xl xm:h-[474px] xm:w-[354px]
				{longWord ? 'py-32 text-4xl' : 'text-5xl'} flex items-center justify-center border
				shadow-sm bg-dotted-spacing-8 bg-dotted-gray-200 sm:h-[32rem] sm:w-[32rem]"
	>
		{#if currentFlashcardType === 'kanji'}
			<span class="text-9xl sm:text-[14rem]">
				{$currentFlashcard}
			</span>
		{:else}
			<p class="vertical text-5xl leading-loose tracking-widest">
				{@html currentFlashcardFurigana}
			</p>
		{/if}

		<button
			class="fixed bottom-5 left-5 z-30 rounded-full border bg-white p-2 shadow-sm transition-all
				{showNotes && 'hidden'}"
			on:click={() => {
				goto(
					`/flashcards/draw/${
						currentFlashcardType === 'kanji'
							? `kanji-${$page.url.pathname.split('/').at(-1)}-${currentIndex}`
							: currentIndex
					}`
				);
			}}
		>
			<PenTool class="h-4 w-4" />
		</button>

		<button
			class="{showNotes && 'hidden'} 
						fixed bottom-5 right-5 z-30 rounded-full border bg-white p-2 shadow-sm transition-all"
			on:click={() => ($rotateYCard < 40 ? rotateYCard.set(180) : rotateYCard.set(0))}
		>
			<RotateCcw class="h-4 w-4" />
		</button>
	</div>

	<div
		style={`transform: rotateY(${180 - $rotateYCard}deg); backface-visibility: hidden;`}
		class="relative z-10 mx-auto
				{$rotateYCard > 90 ? 'block' : 'hidden'} 
				 flex flex-col
				 {$currentAlphabet === 'kanji' ? 'gap-1' : 'gap-5'}  
				 h-[300px] w-[240px] justify-center overflow-hidden rounded-xl border p-5 shadow-sm xm:h-[474px] xm:w-[354px] sm:h-[32rem] sm:w-[32rem] sm:p-10"
	>
		{#if currentFlashcardType === 'kanji'}
			<div
				class="grid-rows-[max-content max-content] sm:grid-rows-[max-content 1fr] grid h-full grid-cols-2 sm:gap-0"
			>
				<h2 class="col-span-2 text-center text-6xl sm:text-9xl">{$currentFlashcard}</h2>
				<div>
					<h2 class="text-lg font-medium sm:text-4xl">{flashcard.meaning}</h2>
					<p class=" text-sm text-gray-300">Meaning</p>
				</div>
				<div>
					<h4 class="text-lg tracking-widest">{flashcard.onyomi}</h4>
					<p class=" text-sm text-gray-300">Onyomi</p>
				</div>
				{#if flashcard.kunyomi.length > 0}
					<div>
						<h4 class="text-lg tracking-widest">{flashcard.kunyomi}</h4>
						<p class=" text-sm text-gray-300">Kunyomi</p>
					</div>
				{/if}
				{#if flashcards.at(currentIndex) && flashcards.at(currentIndex).notes && flashcards.at(currentIndex).notes.length > 0}
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
							{flashcards.at(currentIndex).notes}
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
				class="grid-rows-[max-content max-content] sm:grid-rows-[max-content 1fr] grid h-full grid-cols-2 sm:gap-0"
			>
				<h2 class="col-span-2 text-center text-4xl">{$currentFlashcard}</h2>
				<div>
					<h2 class="text-xl font-medium">
						{flashcards.at(currentIndex) && flashcards.at(currentIndex).meaning}
					</h2>
					<p class=" text-sm text-gray-300">Meaning</p>
				</div>
				{#if flashcards.at(currentIndex) && flashcards.at(currentIndex).customFurigana}
					<div>
						<h2 class="text-xl font-medium">{flashcards.at(currentIndex).customFurigana}</h2>
						<p class=" text-sm text-gray-300">Furigana</p>
					</div>
				{/if}
				{#if flashcards.at(currentIndex) && flashcards.at(currentIndex).romanji}
					<div>
						<h2 class="text-xl font-medium">{flashcards.at(currentIndex).romanji}</h2>
						<p class=" text-sm text-gray-300">Romanji/Furigana</p>
					</div>
				{/if}
				{#if flashcards.at(currentIndex) && flashcards.at(currentIndex)?.notes.length > 0}
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
							{flashcards.at(currentIndex).notes}
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
