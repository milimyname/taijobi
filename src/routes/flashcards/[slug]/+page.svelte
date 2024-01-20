<script lang="ts">
	import Flashcard from './Flashcard.svelte';
	import {
		clickedEditFlashcard,
		clickedAddFlashcardCollection,
		flashcardsBoxType,
		currentFlashcard,
		currentIndexStore,
		showLetterDrawing,
		currentFlashcardTypeStore
	} from '$lib/utils/stores';
	import { superForm } from 'sveltekit-superforms/client';
	import FlashcardForm from '$lib/components/forms/flashcard-form-ui.svelte';
	import { page } from '$app/stores';
	import EditButton from './EditButton.svelte';
	import { getLocalStorageItem } from '$lib/utils/localStorage';
	import { onMount } from 'svelte';
	import Swiper from 'swiper';
	import 'swiper/swiper-bundle.css';
	import LetterDrawingFlashcard from './LetterDrawingFlashcard.svelte';
	import { Plus } from 'lucide-svelte';

	export let data;

	// Get the alphabet store length
	let currentFlashcardFurigana: string;
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
			// $clickedEditFlashcard = false;
			$clickedAddFlashcardCollection = false;

			if (form.action.search.endsWith('delete')) currentIndex = 0;
		},
		onUpdated: () => {
			if ($errors.name) return ($clickedAddFlashcardCollection = true);

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

		const savedIndex = localStorage.getItem('swiperActiveIndex');
		if (savedIndex !== null && data.flashcards.length > 0) {
			$currentIndexStore = +savedIndex;
			swiperInstance.slideTo($currentIndexStore);
		} else $currentIndexStore = swiperInstance.activeIndex;
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

	$: if (data.flashcards.length > 0) {
		$currentFlashcard = data.flashcards.at(currentIndex).name;
		currentFlashcardFurigana = data.flashcards.at(currentIndex).furigana;
		$currentFlashcardTypeStore = data.flashcards.at(currentIndex).type;
	} else $currentFlashcardTypeStore = 'word';

	$: if ($currentIndexStore && swiperInstance) {
		swiperInstance.activeIndex = $currentIndexStore;

		// Set to local storage
		localStorage.setItem('swiperActiveIndex', '' + $currentIndexStore);
	}
</script>

{#if ($flashcardsBoxType !== 'original' && islocalBoxTypeOriginal) || $page.data.isAdmin}
	<FlashcardForm {constraints} {form} {errors} {enhance} />
{/if}

<section
	class="mb-10 sm:mb-20
	{!$showLetterDrawing && 'gap-5'} 
	{data.flashcards.length > 0 ? 'items-center' : 'w-full max-w-md'} 
	flex flex-1 flex-col justify-center"
>
	{#if data.flashcards.length > 0}
		{#if !$showLetterDrawing}
			<Flashcard
				flashcards={data.flashcards}
				{currentIndex}
				longWord={$currentFlashcard.length > 8}
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
	{:else}
		<button
			class="add-form-btn flex h-80 items-center justify-center rounded-xl border-4 border-blue-400 text-center text-xl font-bold text-blue-500 hover:border-blue-500"
			on:click={() => ($clickedAddFlashcardCollection = true)}
		>
			<Plus class="h-10 w-10" />
		</button>
	{/if}

	<div
		class="swiper-container fixed bottom-5 flex h-12 cursor-ew-resize items-center justify-between gap-5 sm:bottom-10 lg:bottom-5"
	>
		<div class="swiper-wrapper">
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
