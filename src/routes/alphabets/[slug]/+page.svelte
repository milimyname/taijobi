<script lang="ts">
	import type { Ctx } from '$lib/utils/ambient.d.ts';
	import { onMount } from 'svelte';
	import { ArrowRight, ArrowLeft, RotateCcw, Heart } from 'lucide-svelte';
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
	import QuizForm from '$lib/components/forms/quiz-form-ui.svelte';
	import { superForm } from 'sveltekit-superforms/client';
	import { page } from '$app/stores';
	import BacksideCard from '$lib/components/canvas/BacksideCard.svelte';
	import DrawingNav from '$lib/components/DrawingNav.svelte';
	import ProgressSlider from '$lib/components/ProgressSlider.svelte';
	import * as Select from '$lib/components/ui/select';
	import { getFlashcardWidth } from '$lib/utils';
	import { quizSchema } from '$lib/utils/zodSchema';
	import { goto } from '$app/navigation';

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

	$: if (data.isLoggedIn) {
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
	const superFrmQuiz = superForm(data.quizForm, {
		validators: quizSchema,
		taintedMessage: null,
		resetForm: true,
		applyAction: true,
		onSubmit: () => ($clickedQuizForm = false),
		onError: () => ($clickedQuizForm = true)
	});
</script>

<QuizForm form={superFrmQuiz} />

<section class=" flex flex-1 flex-col justify-center gap-2 sm:justify-center sm:gap-5">
	<div style="perspective: 3000px; position: relative; overflow: hidden;">
		<div>
			<Canvas rotationY={$rotateYCard} {canvas} {ctx} />

			<!-- SVG  -->
			<Letter rotationY={$rotateYCard} saved={data.flashcard} />

			{#if $currentAlphabet === 'kanji'}
				<button
					on:click={() => {
						if (!$page.data.isLoggedIn) return goto('/login');
						handleSavedKanji();
						savedKanji = !savedKanji;
					}}
					class="{$rotateYCard > 5 ? 'hidden' : 'text-black'} 
				fixed left-3 top-3 z-30 text-lg font-medium sm:left-5 sm:top-5"
				>
					<Heart
						class="h-6 w-6 transition-all {savedKanji &&
							'fill-black'} hover:scale-110 active:scale-110"
					/>
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
			<Select.Root
				name="kanji-grade"
				onSelectedChange={(selected) => {
					if (selected) $selectedKanjiGrade = '' + selected.value;
					$progressSlider = Math.floor(Math.random() * $kanjiLength);
				}}
			>
				<Select.Trigger class="w-32 border-0 focus:ring-0 focus:ring-offset-0">
					<Select.Value
						placeholder={$selectedKanjiGrade === '0' ? 'All Grades' : $selectedKanjiGrade}
						class="w-full"
					/>
				</Select.Trigger>
				<Select.Content>
					<Select.Item value="0">All Grades</Select.Item>
					<Select.Item value="1">Grade 1</Select.Item>
					<Select.Item value="2">Grade 2</Select.Item>
					<Select.Item value="3">Grade 3</Select.Item>
					<Select.Item value="4">Grade 4</Select.Item>
					<Select.Item value="5">Grade 5</Select.Item>
					<Select.Item value="6">Grade 6</Select.Item>
					{#if $page.data.isLoggedIn}
						<Select.Item value="saved">My Saved</Select.Item>
					{/if}
				</Select.Content>
			</Select.Root>
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
