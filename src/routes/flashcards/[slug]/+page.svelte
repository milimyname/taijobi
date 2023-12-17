<script lang="ts">
	import Flashcard from './Flashcard.svelte';
	import {
		clickedEditFlashcard,
		clickedAddFlashcardCollection,
		flashcardsBoxType,
		currentFlashcard,
		currentIndexStore
	} from '$lib/utils/stores';
	import { superForm } from 'sveltekit-superforms/client';
	import { clickOutside } from '$lib/utils/clickOutside.js';
	import FlashcardForm from '$lib/components/forms/FlashcardForm.svelte';
	import { page } from '$app/stores';
	import EditButton from './EditButton.svelte';
	import { getLocalStorageItem } from '$lib/utils/localStorage';
	import { onMount } from 'svelte';
	import Swiper from 'swiper';
	import { Navigation, Pagination } from 'swiper/modules';
	import 'swiper/swiper-bundle.css';

	export let data;

	let flashcards = data.flashcards;

	// Get the alphabet store length
	let currentFlashcardFurigana: string;
	let currentFlashcardType: string;
	let currentIndex: number = $currentIndexStore
		? $currentIndexStore
		: Math.floor(flashcards.length / 2);
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
			if (swiperInstance.slides.length + 1 === flashcards.length)
				setTimeout(() => {
					swiperInstance.slideTo(flashcards.length + 1);
				}, 500);
		}
	});

	onMount(() => {
		swiperInstance = new Swiper('.swiper-container', {
			modules: [Navigation, Pagination],
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
		swiperInstance.activeIndex = Math.floor(flashcards.length / 2);
	});

	function updateCurrentFlashcard() {
		if (swiperInstance && typeof swiperInstance.realIndex !== 'undefined') {
			let activeIndex = swiperInstance.activeIndex;
			$currentFlashcard = flashcards[activeIndex].name;
			currentIndex = activeIndex;
			$currentIndexStore = activeIndex;
		} else console.error('Swiper instance is not defined or realIndex is unavailable');
	}

	$: if (flashcards.length > 0) {
		$currentFlashcard = flashcards.at(currentIndex).name;
		currentFlashcardFurigana = flashcards.at(currentIndex).furigana;
		currentFlashcardType = flashcards.at(currentIndex).type;
	}

	$: if (data.streamed.flashcards.length > 0) {
		flashcards = [...data.flashcards, ...data.streamed.flashcards];
	}

	$: if ($currentIndexStore && swiperInstance) swiperInstance.activeIndex = $currentIndexStore;
</script>

{#if ($flashcardsBoxType !== 'original' && islocalBoxTypeOriginal) || $page.data.isAdmin}
	<FlashcardForm {currentFlashcardType} {constraints} {form} {errors} {enhance} />
{/if}

<section
	class="mb-10 flex flex-1 flex-col items-center justify-center gap-2 sm:gap-5"
	use:clickOutside={() => {
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
	{#if flashcards.length > 0}
		<Flashcard
			{flashcards}
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
					<EditButton {form} {flashcards} {currentIndex} />
				</div>
			{/if}
		</div>
	{/if}

	<div
		class="swiper-container -z-1 fixed bottom-5 flex cursor-ew-resize items-center justify-between gap-5 overflow-x-hidden sm:bottom-5"
	>
		<div class="swiper-wrapper mt-40">
			{#await data.streamed.flashcards}
				{#each data.flashcards as flashcard, index}
					<div
						style="display: flex; justify-content: center; width: fit-content"
						class="swiper-slide"
					>
						<button class="text-2xl sm:text-4xl" on:click={() => swiperInstance.slideTo(index)}>
							{flashcard.name}
						</button>
					</div>
				{/each}
			{:then restOfFlashcards}
				{#each [...data.flashcards, ...restOfFlashcards] as flashcard, index}
					<div
						style="display: flex; justify-content: center; width: fit-content"
						class="swiper-slide"
					>
						<button class="text-2xl sm:text-4xl" on:click={() => swiperInstance.slideTo(index)}>
							{flashcard.name}
						</button>
					</div>
				{/each}
			{:catch error}
				<div class="swiper-slide">
					{error.message}
				</div>
			{/await}
		</div>
		<div class="swiper-pagination" />
		<!-- Add navigation buttons if needed -->
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
