<script lang="ts">
	import { kanjiStore, randomNumberSlider } from '$lib/utils/stores';
	import { onMount } from 'svelte';
	import {
		progressSlider,
		currentLetter,
		hiraganaStore,
		katakanaStore,
		currentAlphabet
	} from '$lib/utils/stores';
	import { cubicOut } from 'svelte/easing';
	import { tweened } from 'svelte/motion';
	import { icons } from '$lib/utils/icons';
	import { clearCanvas, getRandomNumber } from '$lib/utils/actions';
	import { toRomaji } from 'wanakana';
	import { goto } from '$app/navigation';
	import { page } from '$app/stores';
	import Letter from '../Letter.svelte';
	import Canvas from '../Canvas.svelte';
	import { kanji } from '$lib/static/kanji';
	import { pocketbase } from '$lib/utils/pocketbase';

	export let data;

	const rotateYCard = tweened(0, {
		duration: 2000,
		easing: cubicOut
	});
	// Get the alphabet store length
	let alphabetLengh: number;
	let canvas: HTMLCanvasElement,
		ctx: {
			strokeStyle: string;
			beginPath: () => void;
			moveTo: (arg0: number, arg1: number) => void;
			lineTo: (arg0: number, arg1: number) => void;
			stroke: () => void;
			lineWidth: number;
			lineJoin: string;
			lineCap: string;
		};

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
		data.flashcards.forEach((flashcard: { word: string }) => {
			if (flashcard.word === $currentLetter) savedKanji = true;
		});

		// Set the progress slider to the current letter
		$randomNumberSlider =
			$currentAlphabet === 'kanji' ? getRandomNumber(1, 240) : getRandomNumber(1, 46);
	}

	// Create/delete a flashcard for kanji
	const handleSavedKanji = async () => {
		let card;
		try {
			// Remove the word from db
			card = await pocketbase.collection('flashcards').getFirstListItem(`word="${$currentLetter}"`);

			await pocketbase.collection('flashcards').delete(card.id);

			// Remove the word from the flashcards array
			data.flashcards = data.flashcards.filter((flashcard) => flashcard.word !== $currentLetter);
		} catch (e) {
			// Create a new flash card
			await pocketbase.collection('flashcards').create({
				word: $currentLetter,
				meaning: kanji[$currentLetter].meaning,
				user_id: data.user.id,
				type: 'kanji'
			});

			// Add the word to the flashcards array
			data.flashcards = [
				...data.flashcards,
				{
					word: $currentLetter
				}
			];
		}
	};

	// Get canvas and context
	onMount(() => {
		canvas = document.querySelector('canvas');
		ctx = canvas.getContext('2d');
	});
</script>

<section class="flex flex-1 flex-col justify-center gap-3 sm:gap-10">
	<button
		on:click={() => {
			goto('/alphabets');
		}}
		class="flex items-center gap-2 sm:hidden"
	>
		{@html icons.previous}
		<span>Back</span>
	</button>
	<Letter rotationY={$rotateYCard} />
	<div style="perspective: 3000px; position: relative;" class="mb-10">
		<Canvas rotationY={$rotateYCard} {canvas} {ctx} />

		<div
			style={`transform: rotateY(${180 - $rotateYCard}deg); backface-visibility: hidden;`}
			class="relative z-10 mx-auto
				{$rotateYCard > 90 ? 'block' : 'hidden'} 
				 flex h-[504px] w-[354px] flex-col
				 {$currentAlphabet === 'kanji' ? 'gap-1' : 'gap-5'}  
				 rounded-xl border p-10 shadow-sm sm:h-[600px] sm:w-[600px]"
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
					{#if kanji[$currentLetter].kunyomi.length > 0}
						<div>
							<h4 class="text-lg tracking-widest">{kanji[$currentLetter].kunyomi}</h4>
							<p class=" text-sm text-gray-300">Kunyomi</p>
						</div>
					{/if}
				</div>
			{:else}
				<h2 class="text-center text-9xl font-medium">{toRomaji($currentLetter).toUpperCase()}</h2>
				<p class="text-center text-lg">Romanji</p>
			{/if}
		</div>

		{#if $currentAlphabet === 'kanji'}
			<button
				on:click={() => {
					handleSavedKanji();
					savedKanji = !savedKanji;
				}}
				class="{$rotateYCard > 5 ? 'hidden' : 'text-black'} 
				fixed left-5 top-5 z-30 text-lg font-medium md:right-40 lg:right-96"
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
				: 'text-black'} fixed right-5 top-5 z-30 text-lg font-medium md:right-40 lg:right-96"
		>
			{$currentLetter}
		</span>

		<button
			on:click|preventDefault={() => {
				clearCanvas(ctx, canvas);
				$progressSlider > 1 ? $progressSlider-- : $progressSlider;
			}}
			class="previousLetter fixed -bottom-10 z-30 rounded-full border bg-white p-2 shadow-sm transition-all lg:left-[22rem]"
		>
			{@html icons.previous}
		</button>

		<button
			on:click|preventDefault={() => {
				clearCanvas(ctx, canvas);
				$progressSlider < alphabetLengh ? $progressSlider++ : $progressSlider;
			}}
			class="previousLetter fixed -bottom-10 right-0 z-30 rounded-full border bg-white p-2 shadow-sm transition-all lg:right-[22rem]"
		>
			{@html icons.next}
		</button>

		<button
			class="{$rotateYCard > 5 && $rotateYCard < 175 ? 'hidden' : 'block'}
				fixed bottom-5 right-5 z-30 rounded-full border bg-white p-2 shadow-sm transition-all md:right-40 lg:right-96"
			on:click={() => {
				$rotateYCard < 40 ? rotateYCard.set(180) : rotateYCard.set(0);
			}}
		>
			{@html icons.backside}
		</button>
	</div>
</section>
