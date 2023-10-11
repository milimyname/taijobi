<script lang="ts">
	import type { Ctx } from '$lib/utils/ambient.d.ts';
	import { kanjiStore } from '$lib/utils/stores';
	import { onMount } from 'svelte';
	import {
		progressSlider,
		currentLetter,
		hiraganaStore,
		katakanaStore,
		currentAlphabet,
		selectedKanjiGrade,
		searchKanji
	} from '$lib/utils/stores';
	import { cubicOut } from 'svelte/easing';
	import { tweened } from 'svelte/motion';
	import { icons } from '$lib/utils/icons';
	import { clearCanvas } from '$lib/utils/actions';
	import { toRomaji } from 'wanakana';
	import { goto } from '$app/navigation';
	import { page } from '$app/stores';
	import Letter from '../Letter.svelte';
	import Canvas from '../Canvas.svelte';
	import { kanji } from '$lib/static/kanji';
	import { pocketbase } from '$lib/utils/pocketbase';
	import { canvasLgHeight, canvasLgWidth } from '$lib/utils/constants';

	export let data;

	const rotateYCard = tweened(0, {
		duration: 2000,
		easing: cubicOut
	});
	// Get the alphabet store length
	let alphabetLengh: number;
	let canvas: HTMLCanvasElement;
	let ctx: Ctx;

	let savedKanji: boolean = false;

	// Get the last segment of the URL path (assuming it contains the identifier you need)
	$currentAlphabet = $page.url.pathname.split('/').pop() as 'hiragana' | 'katakana' | 'kanji';

	$: {
		switch ($currentAlphabet) {
			case 'katakana':
				alphabetLengh = $katakanaStore.length;
				break;
			case 'kanji':
				alphabetLengh = $kanjiStore.length;
				break;
			default:
				alphabetLengh = $hiraganaStore.length;
		}

		// Check whether the current letter is saved in the db
		savedKanji = false;
		data.flashcard.forEach((flashcard: { name: string }) => {
			if (flashcard.name === $currentLetter) savedKanji = true;
		});
	}

	// Create/delete a flashcard for kanji
	const handleSavedKanji = async () => {
		let card;
		try {
			// Remove the name from db
			card = await pocketbase.collection('flashcard').getFirstListItem(`name="${$currentLetter}"`);

			await pocketbase.collection('flashcard').delete(card.id);

			// Remove the name from the flashcards array
			data.flashcard = data.flashcard.filter(
				(flashcard: { name: string }) => flashcard.name !== $currentLetter
			);
		} catch (e) {
			// Create a new flash card
			await pocketbase.collection('flashcard').create({
				name: $currentLetter,
				meaning: kanji[$currentLetter].meaning,
				flashcardsId: data.kanji_id,
				type: 'kanji'
			});

			// Add the word to the flashcards array
			data.flashcard = [
				...data.flashcard,
				{
					name: $currentLetter
				}
			];
		}
	};

	// Get canvas and context
	onMount(() => {
		canvas = document.querySelector('canvas') as HTMLCanvasElement;
		ctx = canvas.getContext('2d') as Ctx;

		// Get the last segment of the URL path (assuming it contains the identifier you need)
		$currentAlphabet = $page.url.pathname.split('/').pop() as 'hiragana' | 'katakana' | 'kanji';
	});
</script>

<section class="flex flex-1 flex-col justify-center gap-2 sm:gap-5">
	<div class="relative flex justify-between">
		<button on:click={() => goto('/')} class="flex items-center gap-2">
			{@html icons.previous}
			<span>Back</span>
		</button>

		{#if $currentAlphabet === 'kanji'}
			<div class="kanji-search">
				<label for="search">
					{@html icons.search}
				</label>
				<input
					type="text"
					id="search"
					bind:value={$searchKanji}
					on:input={(e) => {
						// Limit the search to one character
						if (e.target.value.length > 1) e.target.value = e.target.value.slice(0, 1);
					}}
					autocomplete="off"
					class="w-14 border-hidden bg-white outline-none focus:border-transparent focus:bg-transparent focus:ring-0 focus:ring-transparent"
				/>
			</div>
		{/if}
	</div>

	<div style="perspective: 3000px; position: relative;">
		<div>
			<Canvas rotationY={$rotateYCard} {canvas} {ctx} />

			<!-- SVG  -->
			<Letter rotationY={$rotateYCard} saved={data.flashcard} />

			{#if $currentAlphabet === 'kanji'}
				<button
					on:click={() => {
						handleSavedKanji();
						savedKanji = !savedKanji;
					}}
					class="{$rotateYCard > 5 ? 'hidden' : 'text-black'} 
				fixed left-5 top-5 z-30 text-lg font-medium"
				>
					<svg
						xmlns="http://www.w3.org/2000/svg"
						fill="none"
						viewBox="0 0 24 24"
						stroke-width="1.5"
						stroke="currentColor"
						class="h-6 w-6 transition-all {savedKanji &&
							'fill-black'} hover:scale-110 active:scale-110"
					>
						<path
							stroke-linecap="round"
							stroke-linejoin="round"
							d="M21 8.25c0-2.485-2.099-4.5-4.688-4.5-1.935 0-3.597 1.126-4.312 2.733-.715-1.607-2.377-2.733-4.313-2.733C5.1 3.75 3 5.765 3 8.25c0 7.22 9 12 9 12s9-4.78 9-12z"
						/>
					</svg>
				</button>
			{/if}

			<span
				class="{$rotateYCard > 5
					? 'hidden'
					: 'text-black'} fixed right-5 top-5 z-30 text-lg font-medium"
			>
				{$currentLetter}
			</span>

			<button
				class="{$rotateYCard > 5 && $rotateYCard < 175 ? 'hidden' : 'block'}
				fixed bottom-5 right-5 z-30 rounded-full border bg-white p-2 shadow-sm transition-all"
				on:click={() => {
					$rotateYCard < 40 ? rotateYCard.set(180) : rotateYCard.set(0);
				}}
			>
				{@html icons.backside}
			</button>
		</div>

		<div
			style={`transform: rotateY(${180 - $rotateYCard}deg); backface-visibility: hidden;`}
			class="relative z-10 mx-auto
				{$rotateYCard > 90 ? 'block' : 'hidden'} 
				 flex h-[504px] w-[354px] flex-col
				 {$currentAlphabet === 'kanji' ? 'gap-1' : 'gap-5'}  
				 justify-center rounded-xl border p-10 shadow-sm sm:h-[{canvasLgHeight}px] sm:w-[{canvasLgWidth}px]"
		>
			{#if $currentAlphabet === 'kanji'}
				<div class="grid-rows-[max-content 1fr] grid h-full">
					<h2 class="text-center text-9xl">{$currentLetter}</h2>
					<div>
						<h2 class="text-4xl font-medium">{kanji[$currentLetter].meaning}</h2>
						<p class=" text-sm text-gray-300">Meaning</p>
					</div>
					<div>
						<h4 class="text-lg tracking-widest">{kanji[$currentLetter].onyomi}</h4>
						<p class=" text-sm text-gray-300">Onyomi</p>
					</div>
					{#if kanji[$currentLetter].kunyomi && kanji[$currentLetter].kunyomi.length > 0}
						<div>
							<h4 class="text-lg tracking-widest">{kanji[$currentLetter].kunyomi}</h4>
							<p class="text-sm text-gray-300">Kunyomi</p>
						</div>
					{/if}
				</div>
			{:else}
				<h2 class="text-center text-9xl font-medium">{toRomaji($currentLetter).toUpperCase()}</h2>
				<p class="text-center text-lg">Romanji</p>
			{/if}
		</div>
	</div>

	<div class="flex items-center justify-between sm:mx-auto sm:w-[{canvasLgWidth}px]">
		<button
			on:click|preventDefault={() => {
				clearCanvas(ctx, canvas);
				$progressSlider > 1 ? $progressSlider-- : $progressSlider;
				$searchKanji = '';
			}}
			class="previousLetter h-fit w-fit rounded-full border bg-white p-2 shadow-sm transition-all"
		>
			{@html icons.previous}
		</button>

		{#if $currentAlphabet === 'kanji'}
			<select
				name="kanji-grade"
				id="kanji-grade"
				class="border-hidden bg-none pr-3 text-center outline-none focus:border-transparent focus:ring-0"
				bind:value={$selectedKanjiGrade}
			>
				<option value="0">All Grades</option>
				<option value="1">Grade 1</option>
				<option value="2">Grade 2</option>
				<option value="3">Grade 3</option>
				<option value="4">Grade 4</option>
				<option value="5">Grade 5</option>
				<option value="6">Grade 6</option>
				<option value="saved">My Saved</option>
			</select>
		{/if}

		<button
			on:click|preventDefault={() => {
				clearCanvas(ctx, canvas);
				$progressSlider < alphabetLengh ? $progressSlider++ : $progressSlider;
				$searchKanji = '';
			}}
			class="previousLetter h-fit w-fit rounded-full border bg-white p-2 shadow-sm transition-all"
		>
			{@html icons.next}
		</button>
	</div>
</section>
