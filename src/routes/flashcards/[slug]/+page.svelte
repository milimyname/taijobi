<script lang="ts">
	import Flashcard from './flashcard-plain.svelte';
	import Skeleton from './flashcard-skeleton.svelte';
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
	import { flashcardSchema } from '$lib/utils/zodSchema';
	import type { FlashcardType } from '$lib/utils/ambient.d.ts';
	import { browser } from '$app/environment';

	export let data;

	// Get the alphabet store length
	let currentFlashcardFurigana: string;
	let currentIndex: number = 0;
	let flashcards: FlashcardType[] = [];
	let isLoading = false;

	let islocalBoxTypeOriginal = getLocalStorageItem('flashcardsBoxType') !== 'original';
	let swiperInstance: Swiper;

	// Fetch flashcards from the server
	async function fetchFlashcards() {
		isLoading = true;
		try {
			const res = await fetch(`/flashcards/${$page.params.slug}`);
			const data = await res.json();
			return data;
		} catch (error) {
			console.error(error);
		}
		isLoading = false;
	}

	// Client API:
	const superFrm = superForm(data.form, {
		validators: flashcardSchema,
		taintedMessage: null,
		resetForm: true,
		applyAction: true,
		onSubmit: async (form) => {
			$clickedEditFlashcard = false;
			$clickedAddFlashcardCollection = false;

			if (form.action.search.endsWith('delete')) currentIndex = 0;
		},
		onUpdated: async ({ form }) => {
			// Keep the form open if there is an error
			if (form.errors.type || form.errors.name) $clickedAddFlashcardCollection = true;

			// Update the flashcards
			const data = await fetchFlashcards();
			flashcards = data.flashcards;

			// Slide to the new created word
			if (swiperInstance.slides.length + 1 === flashcards.length) {
				// Update slides
				swiperInstance.update();

				setTimeout(() => {
					swiperInstance.slideTo(flashcards.length + 1);
				}, 100);
			}
		}
	});

	onMount(async () => {
		swiperInstance = new Swiper('.swiper-container', {
			slidesPerView: 'auto',
			centeredSlides: true,
			spaceBetween: 30,
			slideToClickedSlide: true,
			grabCursor: true,
			on: {
				slideChange: (swiper) => {
					currentIndex = swiper.activeIndex;
					$currentIndexStore = swiper.activeIndex;
				}
			}
		});

		const data = await fetchFlashcards();
		flashcards = data.flashcards;

		// Set the initial flashcard
		swiperInstance.activeIndex = $currentIndexStore
			? $currentIndexStore
			: Math.floor(flashcards.length / 2);

		const savedIndex = localStorage.getItem('swiperActiveIndex');
		if (savedIndex !== null && flashcards.length > 0) {
			$currentIndexStore = +savedIndex;
			swiperInstance.slideTo($currentIndexStore);
		} else $currentIndexStore = swiperInstance.activeIndex;
	});

	$: if (browser && currentIndex >= 0 && flashcards.length > 0) {
		const card = flashcards.at(currentIndex);
		if (card) {
			// Check if currentFlashcard is not undefined
			$currentFlashcard = card.name;
			currentFlashcardFurigana = card.furigana || '';
			$currentFlashcardTypeStore = card.type || 'word';
		}
	}

	$: if ($currentIndexStore && swiperInstance) {
		swiperInstance.activeIndex = $currentIndexStore;
		// Set to local storage
		localStorage.setItem('swiperActiveIndex', '' + $currentIndexStore);
	}

	$: flashcards.length === 0 && (isLoading = false);
</script>

{#if ($flashcardsBoxType !== 'original' && islocalBoxTypeOriginal) || $page.isAdmin}
	<FlashcardForm form={superFrm} />
{/if}

<section
	class="mb-10 sm:mb-20
	{!$showLetterDrawing && 'gap-5'} 
	{flashcards.length > 0 ? 'items-center' : 'w-full max-w-md'} 
	flex flex-1 flex-col justify-center"
>
	{#if flashcards.length > 0}
		{#if !$showLetterDrawing}
			<Flashcard
				wordFlashcard={flashcards.at(currentIndex)}
				{currentIndex}
				longWord={$currentFlashcard.length > 8}
				{currentFlashcardFurigana}
			/>

			<div class="flex items-center justify-center sm:mx-auto sm:w-[600px]">
				{#if ($flashcardsBoxType !== 'original' && islocalBoxTypeOriginal) || $page.isAdmin}
					<EditButton form={superFrm.form} currentFlashcard={flashcards[currentIndex]} />
				{/if}
			</div>
		{:else}
			<LetterDrawingFlashcard {swiperInstance} />
		{/if}
	{:else if !isLoading}
		<button
			class="add-form-btn flex h-80 items-center justify-center rounded-xl border-4 border-blue-400 text-center text-xl font-bold text-blue-500 hover:border-blue-500"
			on:click={() => ($clickedAddFlashcardCollection = true)}
		>
			<Plus class="h-10 w-10" />
		</button>
	{:else}
		<Skeleton />
	{/if}

	<div
		class="swiper-container fixed bottom-5 flex h-12 cursor-ew-resize items-center justify-between gap-5 sm:bottom-10 lg:bottom-5"
	>
		<div class="swiper-wrapper">
			{#each flashcards as flashcard, index}
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
