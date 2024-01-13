<script lang="ts">
	import type { Ctx } from '$lib/utils/ambient.d.ts';
	import { onMount } from 'svelte';
	import { ArrowRight, ArrowLeft, RotateCcw } from 'lucide-svelte';
	import {
		progressSlider,
		currentLetter,
		hiraganaStore,
		katakanaStore,
		currentAlphabet,
		selectedKanjiGrade,
		searchKanji,
		innerWidthStore,
		clickedQuizForm,
		kanjiStore,
		kanjiLength
	} from '$lib/utils/stores';
	import { cubicOut } from 'svelte/easing';
	import { tweened } from 'svelte/motion';
	import { clearCanvas } from '$lib/utils/actions';
	import Letter from '$lib/components/canvas/Letter.svelte';
	import Canvas from '$lib/components/canvas/Canvas.svelte';
	import { kanji } from '$lib/static/kanji';
	import { pocketbase } from '$lib/utils/pocketbase';
	import TextQuizForm from '$lib/components/forms/TextQuizForm.svelte';
	import { superForm } from 'sveltekit-superforms/client';
	import { page } from '$app/stores';
	import BacksideCard from '$lib/components/canvas/BacksideCard.svelte';
	import DrawingNav from '$lib/components/DrawingNav.svelte';
	import ProgressSlider from '$lib/components/ProgressSlider.svelte';

	import { getFlashcardWidth } from '$lib/utils';

	export let data;

	const rotateYCard = tweened(0, {
		duration: 2000,
		easing: cubicOut
	});
	// Get the alphabet store length
	let alphabetLength: number;
	let canvas: HTMLCanvasElement;
	let ctx: Ctx;

	let savedKanji: boolean = false;

	$: {
		switch ($currentAlphabet) {
			case 'katakana':
				alphabetLength = $katakanaStore.length;
				break;
			case 'kanji':
				alphabetLength = $kanjiStore.length;
				break;
			default:
				alphabetLength = $hiraganaStore.length;
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
				flashcardBox: data.kanjiId,
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
	});

	$: $currentAlphabet = $page.url.pathname.split('/')[2] as 'hiragana' | 'katakana' | 'kanji';

	// Client API:
	const {
		form: quizForm,
		errors: quizErrors,
		constraints: quizConstraints,
		enhance: quizEnhance
	} = superForm(data.quizForm, {
		taintedMessage: null,
		resetForm: true,
		applyAction: true,
		onSubmit: () => ($clickedQuizForm = false),
		onUpdated: () => {
			if ($quizErrors.timeLimit || $quizErrors.maxCount || $quizErrors.name)
				$clickedQuizForm = true;
		}
	});
</script>

<TextQuizForm
	errors={quizErrors}
	enhance={quizEnhance}
	form={quizForm}
	constraints={quizConstraints}
/>

<section class="mb-10 flex flex-1 flex-col justify-center gap-2 sm:justify-center sm:gap-5">
	<div style="perspective: 3000px; position: relative; overflow: hidden;">
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
				fixed left-3 top-3 z-30 text-lg font-medium sm:left-5 sm:top-5"
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
					: 'text-black'} fixed right-3 top-3 z-30 text-lg font-medium sm:right-5 sm:top-5"
			>
				{$currentLetter}
			</span>

			<span
				class="{$rotateYCard > 5 ? 'hidden' : 'block'}
				fixed bottom-3 left-3 z-30 transition-all sm:bottom-5 sm:left-5"
			>
				{$progressSlider}
			</span>

			<button
				class="{$rotateYCard > 5 && $rotateYCard < 175 ? 'hidden' : 'block'}
				fixed bottom-3 right-2 z-30 rounded-full border bg-white p-2 shadow-sm transition-all sm:bottom-5 sm:right-5"
				on:click={() => ($rotateYCard < 40 ? ($rotateYCard = 180) : ($rotateYCard = 0))}
			>
				<RotateCcw class="h-4 w-4" />
			</button>

			<BacksideCard rotateYCard={$rotateYCard} />
		</div>
	</div>

	<div
		style={`width: ${getFlashcardWidth($innerWidthStore)}px;`}
		class="flex items-center justify-between sm:mx-auto"
	>
		<button
			on:click|preventDefault={() => {
				clearCanvas(ctx, canvas);
				$progressSlider > 1 ? $progressSlider-- : $progressSlider;
				$searchKanji = '';
			}}
			class="previousLetter h-fit w-fit rounded-full border bg-white p-2 shadow-sm transition-all"
		>
			<ArrowLeft class="h-4 w-4" />
		</button>

		{#if $currentAlphabet === 'kanji'}
			<select
				name="kanji-grade"
				id="kanji-grade"
				class="border-hidden bg-none pr-3 text-center outline-none focus:border-transparent focus:ring-0"
				bind:value={$selectedKanjiGrade}
				on:change={() => ($progressSlider = Math.floor(Math.random() * $kanjiLength))}
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

		{#if alphabetLength !== $progressSlider && $kanjiLength !== $progressSlider}
			<button
				on:click|preventDefault={() => {
					clearCanvas(ctx, canvas);
					$progressSlider < alphabetLength ? $progressSlider++ : $progressSlider;
					$searchKanji = '';
				}}
				class="previousLetter h-fit w-fit rounded-full border bg-white p-2 shadow-sm transition-all"
			>
				<ArrowRight class="h-4 w-4" />
			</button>
		{:else}
			<button
				on:click|preventDefault={() => {
					clearCanvas(ctx, canvas);
					$progressSlider = 1;
					$searchKanji = '';
				}}
				class="previousLetter h-fit w-fit rounded-full border bg-white px-3 py-1 shadow-sm transition-all"
			>
				1
			</button>
		{/if}
	</div>

	<DrawingNav />
	<ProgressSlider />
</section>
