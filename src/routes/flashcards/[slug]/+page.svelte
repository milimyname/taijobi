<script lang="ts">
	import Flashcard from './Flashcard.svelte';
	import {
		clickedEditFlashcard,
		clickedAddFlashcardCollection,
		flashcardsBoxType,
		currentFlashcard,
		currentIndexStore,
		showLetterDrawing
	} from '$lib/utils/stores';
	import { superForm } from 'sveltekit-superforms/client';
	import FlashcardForm from '$lib/components/forms/FlashcardForm.svelte';
	import { page } from '$app/stores';
	import EditButton from './EditButton.svelte';
	import { getLocalStorageItem } from '$lib/utils/localStorage';
	import { onMount } from 'svelte';
	import Swiper from 'swiper';
	import 'swiper/swiper-bundle.css';
	import LetterDrawingFlashcard from './LetterDrawingFlashcard.svelte';

	export let data;

	// Get the alphabet store length
	let currentFlashcardFurigana: string;
	let currentFlashcardType: string;
	let currentIndex: number = $currentIndexStore
		? $currentIndexStore
		: Math.floor(data.flashcards.length / 2);

	let islocalBoxTypeOriginal = getLocalStorageItem('flashcardsBoxType') !== 'original';
	let swiperInstance: Swiper;

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

			// Slide to the new created word
			if (swiperInstance.slides.length + 1 === data.flashcards.length)
				setTimeout(() => {
					swiperInstance.slideTo(data.flashcards.length + 1);
				}, 500);
		}
	});

	onMount(() => {
		swiperInstance = new Swiper('.swiper-container', {
			slidesPerView: 'auto',
			centeredSlides: true,
			spaceBetween: 30,
			slideToClickedSlide: true,
			grabCursor: true,
			on: {
				slideChange: () => {
					updateCurrentFlashcard();
				}
			}
		});

		// Set the initial flashcard
		swiperInstance.activeIndex = $currentIndexStore
			? $currentIndexStore
			: Math.floor(data.flashcards.length / 2);

		$currentIndexStore = swiperInstance.activeIndex;
	});

	function updateCurrentFlashcard() {
		if (
			swiperInstance &&
			typeof swiperInstance.activeIndex !== 'undefined' &&
			typeof swiperInstance.realIndex !== 'undefined'
		) {
			let activeIndex = swiperInstance.activeIndex;
			$currentFlashcard = data.flashcards[activeIndex].name;
			currentIndex = activeIndex;
			$currentIndexStore = activeIndex;
		} else console.error('Swiper instance is not defined or realIndex is unavailable');
	}

	$: {
		$currentFlashcard = data.flashcards.at(currentIndex).name;
		currentFlashcardFurigana = data.flashcards.at(currentIndex).furigana;
		currentFlashcardType = data.flashcards.at(currentIndex).type;
	}

	$: if ($currentIndexStore && swiperInstance) swiperInstance.activeIndex = $currentIndexStore;
</script>

{#if ($flashcardsBoxType !== 'original' && islocalBoxTypeOriginal) || $page.data.isAdmin}
	<FlashcardForm {currentFlashcardType} {constraints} {form} {errors} {enhance} />
{/if}

<section class="mb-10 flex flex-1 flex-col items-center justify-center gap-2 sm:gap-5">
	{#if data.flashcards && data.flashcards.length > 0 && !$showLetterDrawing}
		<Flashcard
			flashcards={data.flashcards}
			{currentIndex}
			longWord={$currentFlashcard.length > 8}
			{currentFlashcardType}
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
	{:else}
		<LetterDrawingFlashcard {swiperInstance} />
	{/if}

	<div
		class="swiper-container -z-1 fixed bottom-5 flex cursor-ew-resize items-center justify-between gap-5 overflow-x-hidden sm:bottom-10 lg:bottom-5"
	>
		<div class="swiper-wrapper mt-40">
			{#each data.flashcards as flashcard, index}
				{#if flashcard}
					<div
						style="display: flex; justify-content: center; width: fit-content"
						class="swiper-slide"
					>
						<button class="text-2xl sm:text-4xl" on:click={() => swiperInstance.slideTo(index)}>
							{flashcard.name}
						</button>
					</div>
				{/if}
			{/each}
		</div>
	</div>
</section>

<style>
	.swiper-slide:not(.swiper-slide-active) {
		opacity: 0.5;
		transform: scale(0.8);
		transition:
			transform 0.3s,
			opacity 0.3s;
	}

	/* Styles for active slide */
	.swiper-slide-active {
		opacity: 1;
		transform: scale(1);
	}
</style>
