<script lang="ts">
	import Card from './Flashcard.svelte';
	import {
		clickedEditFlashcard,
		clickedAddFlashcardCollection,
		flashcardsBoxType
	} from '$lib/utils/stores';
	import { spring } from 'svelte/motion';
	import { superForm } from 'sveltekit-superforms/client';
	import { clickOutside } from '$lib/utils/clickOutside.js';
	import FlashcardForm from '$lib/components/forms/FlashcardForm.svelte';
	import { wordClasses } from '$lib/utils/constants.js';
	import { page } from '$app/stores';
	import EditButton from './EditButton.svelte';
	import { getLocalStorageItem } from '$lib/utils/localStorage';

	export let data;

	// Get the alphabet store length
	let currentFlashcard: string;
	let currentFlashcardFurigana: string;
	let currentFlashcardType: string;
	let currentIndex: number = Math.floor(data.flashcards.length / 2);
	let islocalBoxTypeOriginal = getLocalStorageItem('flashcardsBoxType') !== 'original';

	// Client API:
	const { form, errors, constraints, enhance } = superForm(data.form, {
		taintedMessage: null,
		resetForm: true,
		applyAction: true,
		onSubmit: async (form) => {
			$clickedEditFlashcard = false;
			$clickedAddFlashcardCollection = false;

			if (form.action.search.endsWith('delete')) currentIndex = 0;
		},
		onUpdated: () => {
			if (!$errors.name) $clickedAddFlashcardCollection = false;
		}
	});

	let initialX = 0; // track the initial X position on drag start
	let initialValue = 0; // track the initial slider value on drag start
	let mousedown = false;
	let sliderWords: HTMLButtonElement;
	let currentlyCenteredWord: HTMLButtonElement;

	let progress = spring(0, {
		stiffness: 0.1,
		damping: 0.4
	});

	const start = (e: any) => {
		mousedown = true;

		initialValue = $progress; // store the initial slider value

		if (e.type === 'touchstart') initialX = e.touches[0].clientX;
		else initialX = e.clientX;
	};

	const end = () => (mousedown = false);

	const move = (e: any) => {
		if (!mousedown) return;

		let currentX;

		currentX = e.type === 'touchmove' ? e.touches[0].clientX : (currentX = e.clientX);

		const deltaX = currentX - initialX; // difference from initial position
		const sensitivity = 2; // adjust as needed for smoother or sharper response
		let change = Math.round(deltaX * sensitivity);

		// Calculate the new progress value
		const newProgress = initialValue + change;

		// Calculate the minimum and maximum values for progress
		const minProgress = -sliderWords.getBoundingClientRect().width / 2;
		const maxProgress = sliderWords.getBoundingClientRect().width / 2;

		// Check if the new progress is within the allowed range
		if (newProgress >= minProgress && newProgress <= maxProgress) $progress = newProgress;
		else if (newProgress < minProgress)
			// If newProgress goes below the minimum, set it to the minimum
			$progress = -maxProgress;
		else if (newProgress > maxProgress)
			// If newProgress goes above the maximum, set it to the maximum
			$progress = maxProgress;

		const words = sliderWords.querySelectorAll('button');

		words.forEach((word: HTMLButtonElement) => {
			const wordLeft = word.getBoundingClientRect().left;
			const width =
				currentFlashcardType === 'kanji'
					? word.getBoundingClientRect().width * 2
					: currentFlashcard.length > 8
					? word.getBoundingClientRect().width
					: word.getBoundingClientRect().width / 2;

			// Check if the word is in the middle of the screen
			if (
				wordLeft > window.innerWidth / 2 - width - 60 &&
				wordLeft < window.innerWidth / 2 + width
			) {
				// Set the current flashcard to the word in the middle of the screen
				if (word !== currentlyCenteredWord) {
					// Remove special styling from the previously centered word
					if (currentlyCenteredWord) {
						currentlyCenteredWord.classList.add('text-gray-200', 'text-2xl');
						currentlyCenteredWord.classList.remove(...wordClasses);
					}
					// Apply special styling to the new centered word
					word.classList.remove('text-gray-200', 'text-2xl');
					word.classList.add(...wordClasses);

					// Update the currently centered word
					currentlyCenteredWord = word;

					currentFlashcard = data.flashcards.at(
						Array.from(words).indexOf(currentlyCenteredWord)
					).name;

					currentFlashcardType = data.flashcards.at(
						Array.from(words).indexOf(currentlyCenteredWord)
					).type;

					currentIndex = Array.from(words).indexOf(currentlyCenteredWord);
				}
			} else {
				// Remove special styling from words that are no longer centered
				word.classList.add('text-gray-200', 'text-2xl');
				word.classList.remove(...wordClasses);
			}

			word.style.transform = `translateX(${$progress}px)`;
		});
	};

	$: if (data.flashcards.length > 0) {
		currentFlashcard = data.flashcards.at(currentIndex).name;
		currentFlashcardFurigana = data.flashcards.at(currentIndex).furigana;
		currentFlashcardType = data.flashcards.at(currentIndex).type;
	}

	const handleClick = (name: string) => {
		return function () {
			currentFlashcard = name;
			currentIndex = data.flashcards.findIndex((flashcard) => flashcard.name === name);
		};
	};
</script>

{#if ($flashcardsBoxType !== 'original' && islocalBoxTypeOriginal) || $page.data.isAdmin}
	<FlashcardForm {currentFlashcardType} {constraints} {form} {errors} {enhance} />
{/if}

<section
	class="mb-10 flex flex-1 flex-col items-center justify-center gap-2 sm:gap-5"
	use:clickOutside
	on:outsideclick={() => {
		$clickedAddFlashcardCollection = false;
		// Clear the form
		$form.name = '';
		$form.meaning = '';
		$form.id = '';
		$form.notes = '';
		$form.type = '';
		$form.romanji = '';
		$form.furigana = '';
	}}
>
	{#if data.flashcards.length > 0}
		<Card
			flashcards={data.flashcards}
			{currentIndex}
			longWord={currentFlashcard.length > 8}
			{currentFlashcardType}
			{currentFlashcard}
			{currentFlashcardFurigana}
		/>

		<div class="flex items-center justify-center sm:mx-auto sm:w-[600px]">
			{#if ($flashcardsBoxType !== 'original' && islocalBoxTypeOriginal) || $page.data.isAdmin}
				<div
					class="flex items-center justify-between gap-8 rounded-full bg-black px-4 py-2 text-white"
				>
					<EditButton {form} flashcards={data.flashcards} {currentIndex} />
				</div>
			{/if}
		</div>
	{/if}

	<button
		bind:this={sliderWords}
		class="fixed bottom-0 flex cursor-ew-resize items-center justify-between gap-5 overflow-x-hidden sm:bottom-5"
		on:mousedown|preventDefault={start}
		on:mouseup|preventDefault={end}
		on:mousemove|preventDefault={move}
		on:touchstart|preventDefault={start}
		on:touchend|preventDefault={end}
		on:touchmove|preventDefault={move}
	>
		{#each data.flashcards as { name }}
			<button
				class="relative w-max {name.length > 5
					? 'h-12 text-lg sm:text-xl'
					: 'h-14 text-xl  sm:text-2xl'} {currentFlashcard === name
					? " text-3xl text-black before:absolute before:left-1/2 before:top-0 before:h-1.5  before:w-1.5 before:-translate-x-1/2 before:rounded-full before:bg-black before:content-['']"
					: 'text-gray-200 '}"
				on:click={handleClick(name)}
				on:touchstart={handleClick(name)}
			>
				{name}
			</button>
		{/each}
	</button>
</section>
