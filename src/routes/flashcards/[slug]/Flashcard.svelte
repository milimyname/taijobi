<script lang="ts">
	import type { FlashcardType } from '$lib/utils/ambient.d.ts';
	import { icons } from '$lib/utils/icons';
	import { kanji } from '$lib/static/kanji';
	import { fly } from 'svelte/transition';
	import { currentAlphabet } from '$lib/utils/stores';
	import { quintOut, cubicOut } from 'svelte/easing';
	import { tweened } from 'svelte/motion';

	const rotateYCard = tweened(0, {
		duration: 2000,
		easing: cubicOut
	});

	let showNotes: boolean = false;

	export let currentFlashcard: string;
	export let flashcards: FlashcardType[];
	export let currentFlashcardFurigana: string;
	export let currentFlashcardType: string;
	export let currentIndex: number;
	export let longWord: boolean;

	let flashcard = kanji[currentFlashcard as keyof typeof kanji];
	let fetchedFlashcard = flashcards.at(currentIndex);
</script>

<div style="perspective: 3000px; position: relative;">
	<div
		style={`transform: rotateY(${-$rotateYCard}deg); transform-style: preserve-3d; backface-visibility: hidden; `}
		class="relative z-10 cursor-pointer
				{$rotateYCard > 90 ? 'hidden' : 'block'} h-[474px] w-[354px] rounded-xl
				{longWord ? 'py-32 text-4xl' : 'text-5xl'} flex items-center justify-center border
				shadow-sm bg-dotted-spacing-8 bg-dotted-gray-200 sm:h-[32rem] sm:w-[32rem]"
	>
		{#if currentFlashcardType === 'kanji'}
			<span class="text-[14rem]">
				{currentFlashcard}
			</span>
		{:else}
			<p class="vertical leading-loose tracking-widest">
				{@html currentFlashcardFurigana}
			</p>
		{/if}

		<button
			class="{showNotes && 'hidden'} 
						fixed bottom-5 right-5 z-30 rounded-full border bg-white p-2 shadow-sm transition-all"
			on:click={() => ($rotateYCard < 40 ? rotateYCard.set(180) : rotateYCard.set(0))}
		>
			{@html icons.backside}
		</button>
	</div>

	<div
		style={`transform: rotateY(${180 - $rotateYCard}deg); backface-visibility: hidden;`}
		class="relative z-10 mx-auto
				{$rotateYCard > 90 ? 'block' : 'hidden'} 
				 flex h-[474px] w-[354px] flex-col
				 {$currentAlphabet === 'kanji' ? 'gap-1' : 'gap-5'}  
				 justify-center overflow-hidden rounded-xl border p-10 shadow-sm sm:h-[32rem] sm:w-[32rem]"
	>
		{#if currentFlashcardType === 'kanji'}
			<div class="grid-rows-[max-content 1fr] grid h-full">
				<h2 class="text-center text-9xl">{currentFlashcard}</h2>
				<div>
					<h2 class="text-4xl font-medium">{flashcard.meaning}</h2>
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
				{#if fetchedFlashcard && fetchedFlashcard.notes && fetchedFlashcard.notes.length > 0}
					<button
						class="fixed bottom-0 left-0 z-10 rounded-tr-xl {showNotes
							? 'bg-white text-black'
							: 'bg-blue-200'} p-5"
						on:click|preventDefault={() => (showNotes = !showNotes)}
					>
						{@html icons.notes}
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
							{fetchedFlashcard.notes}
						</p>
					{/if}
				{/if}
				<button
					class="{showNotes && 'hidden'}
								fixed bottom-5 right-5 z-30 rounded-full border bg-white p-2 shadow-sm transition-all"
					on:click={() => ($rotateYCard < 40 ? rotateYCard.set(180) : rotateYCard.set(0))}
				>
					{@html icons.backside}
				</button>
			</div>
		{:else}
			<div class="grid-rows-[max-content 1fr] grid h-full">
				<h2 class="text-center text-4xl">{currentFlashcard}</h2>
				<div>
					<h2 class="text-xl font-medium">{fetchedFlashcard && fetchedFlashcard.meaning}</h2>
					<p class=" text-sm text-gray-300">Meaning</p>
				</div>
				{#if fetchedFlashcard && fetchedFlashcard.customFurigana}
					<div>
						<h2 class="text-xl font-medium">{fetchedFlashcard.customFurigana}</h2>
						<p class=" text-sm text-gray-300">Furigana</p>
					</div>
				{/if}
				{#if fetchedFlashcard && fetchedFlashcard.romanji}
					<div>
						<h2 class="text-xl font-medium">{fetchedFlashcard.romanji}</h2>
						<p class=" text-sm text-gray-300">Romanji</p>
					</div>
				{/if}
				{#if fetchedFlashcard && fetchedFlashcard?.notes.length > 0}
					<button
						class="fixed bottom-0 left-0 z-10 rounded-tr-xl {showNotes
							? 'bg-white text-black'
							: 'bg-blue-200'} p-5"
						on:click|preventDefault={() => (showNotes = !showNotes)}
					>
						{@html icons.notes}
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
							{fetchedFlashcard.notes}
						</p>
					{/if}
				{/if}
				<button
					class="{showNotes && 'hidden'}
								fixed bottom-5 right-5 z-30 rounded-full border bg-white p-2 shadow-sm transition-all"
					on:click={() => ($rotateYCard < 40 ? rotateYCard.set(180) : rotateYCard.set(0))}
				>
					{@html icons.backside}
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
