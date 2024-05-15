<script lang="ts">
	import Flashcard from './flashcard-plain.svelte';
	import Skeleton from './flashcard-skeleton.svelte';
	import CallBackButton from './callback-btn.svelte';
	import {
		clickedAddFlashcardCollection,
		flashcardsBoxType,
		currentFlashcard,
		currentIndexStore,
		showLetterDrawing,
		currentFlashcardTypeStore,
		searchedWordStore,
		clickedEditFlashcard,
		canIdrawMultipleTimes
	} from '$lib/utils/stores';
	import FlashcardForm from '$lib/components/forms/flashcard-form-ui.svelte';
	import { page } from '$app/stores';
	import EditButton from './EditButton.svelte';
	import { getLocalStorageItem } from '$lib/utils/localStorage';
	import { onMount } from 'svelte';
	import LetterDrawingFlashcard from './LetterDrawingFlashcard.svelte';
	import { Plus, Dices } from 'lucide-svelte';
	import type { FlashcardType } from '$lib/utils/ambient.d.ts';
	import { browser } from '$app/environment';
	import * as Carousel from '$lib/components/ui/carousel/index';
	import { type CarouselAPI } from '$lib/components/ui/carousel/context';
	import { cn } from '$lib/utils';
	import { WheelGesturesPlugin } from 'embla-carousel-wheel-gestures';
	import { superForm } from 'sveltekit-superforms';
	import { zodClient } from 'sveltekit-superforms/adapters';
	import { flashcardSchema } from '$lib/utils/zodSchema';
	import { goto } from '$app/navigation';
	import CarouselWithThumbnails from './carousel-thumbnails.svelte';

	export let data;

	let embla: CarouselAPI;

	// Get the alphabet store length
	let currentFlashcardFurigana: string;
	let currentIndex = 0;
	let flashcards: FlashcardType[] = [];
	let isLoading = false;

	let islocalBoxTypeOriginal = getLocalStorageItem('flashcardsBoxType') !== 'original';

	// Fetch flashcards from the server
	async function fetchFlashcards() {
		isLoading = true;

		try {
			const res = await fetch(`/api/flashcard?id=${$page.params.slug}`);
			const data = await res.json();

			if (data.error) return goto('/flashcards');

			return data;
		} catch (error) {
			console.error(error);
		}
		isLoading = false;
	}

	const form = superForm(data.form, {
		validators: zodClient(flashcardSchema),
		onUpdated: async ({ form }) => {
			// Keep the form open if there is an error
			if (form.errors.type || form.errors.name) return ($clickedAddFlashcardCollection = true);
			else {
				$clickedEditFlashcard = false;
				$clickedAddFlashcardCollection = false;
			}

			// Update the flashcards
			const data = await fetchFlashcards();
			if (data) flashcards = data.flashcards;

			//  Don't slide to the new created word if there are less than 2 words
			if (flashcards.length < 2) return;

			// Slide to the new created word
			if (embla.scrollSnapList().length + 1 === flashcards.length) {
				embla.reInit();

				setTimeout(() => {
					embla.scrollTo(flashcards.length - 1);
					$currentFlashcard = flashcards[flashcards.length - 1].name;
				}, 100);
			}

			// If deleted, move to the previous word
			if (embla.scrollSnapList().length > flashcards.length) {
				embla.reInit();

				setTimeout(() => {
					embla.scrollTo(currentIndex - 1);
					$currentFlashcard = flashcards[currentIndex - 1].name;
				}, 100);
			}
		}
	});

	onMount(async () => {
		const data = await fetchFlashcards();
		if (data) flashcards = data.flashcards;

		// Don't slide to the current flashcard if there are less than 2 words and remove index from localstorage
		if (flashcards.length < 2)
			return localStorage.removeItem(`currentFlashcardIndexOfFlashcards-${$page.params.slug}`);

		// Get the current flashcard index from the local storage
		const index = localStorage.getItem(`currentFlashcardIndexOfFlashcards-${$page.params.slug}`);
		if (index) currentIndex = parseInt(index);

		// Scroll to the current flashcard
		setTimeout(() => {
			embla.scrollTo(currentIndex);
		}, 100);
	});

	$: if (browser && currentIndex >= 0 && flashcards.length > 0) {
		const card = flashcards.at(currentIndex);

		if (card) {
			// Check if currentFlashcard is not undefined
			$currentFlashcard = card.name;
			currentFlashcardFurigana = card.furigana || '';
			$currentFlashcardTypeStore = card.type || 'word';

			// Save current flashcard to local storage
			localStorage.setItem(
				`currentFlashcardIndexOfFlashcards-${$page.params.slug}`,
				currentIndex.toString()
			);
		}
	}

	$: if (embla) {
		$currentIndexStore = currentIndex;
		embla.on('select', () => {
			currentIndex = embla.selectedScrollSnap();
			$currentIndexStore = currentIndex;
		});
	}

	$: flashcards.length === 0 && (isLoading = false);

	$: if ($searchedWordStore) {
		// Find the index of the searched word
		const seachedIndex = flashcards.findIndex(
			(flashcard) => flashcard.name === $searchedWordStore.name
		);

		if (seachedIndex !== -1) {
			currentIndex = seachedIndex;
			$currentIndexStore = seachedIndex;

			// Scroll to the searched word
			setTimeout(() => {
				embla.scrollTo(seachedIndex);
			}, 100);
		}
	}
</script>

<FlashcardForm {form} />

<section
	class={cn(
		'flex h-full w-full flex-col items-center justify-center gap-5 lg:flex-col-reverse',
		!$showLetterDrawing && 'gap-5'
	)}
>
	{#if flashcards.length > 0}
		{#if !$showLetterDrawing && !$canIdrawMultipleTimes}
			<Flashcard
				wordFlashcard={flashcards.at(currentIndex)}
				{currentIndex}
				longWord={$currentFlashcard.length > 8}
				{currentFlashcardFurigana}
			/>

			<div class="flex items-center justify-center sm:mx-auto sm:w-[600px] lg:-order-1">
				<CallBackButton />

				{#if data.isLoggedIn && (($flashcardsBoxType !== 'original' && !islocalBoxTypeOriginal) || $page.data.isAdmin)}
					<EditButton form={form.form} currentFlashcard={flashcards[currentIndex]} />
				{/if}
			</div>
		{/if}

		{#if $showLetterDrawing}
			<LetterDrawingFlashcard  {embla} />
		{/if}

		{#if $canIdrawMultipleTimes}
			<CarouselWithThumbnails {currentIndex} />
		{/if}

		{#if !$canIdrawMultipleTimes}
			<Carousel.Root
				bind:api={embla}
				opts={{
					dragFree: true,
					loop: true
				}}
				plugins={[WheelGesturesPlugin()]}
				class="flaschards-carousel fixed bottom-5 w-2/3 sm:bottom-10 lg:sticky lg:bottom-0 lg:w-5/6"
			>
				<Carousel.Content>
					{#each flashcards as flashcard, index}
						<Carousel.Item
							class={cn(
								'basis-auto scale-75 cursor-pointer text-center text-2xl opacity-50 sm:text-4xl',
								$currentIndexStore === index && '!scale-100  opacity-100',
								flashcards.length < 5 && 'basis-full',
								flashcards.length > 6 && flashcards.length < 10 && 'md:basis-1/3',
								// flashcards.length > 10 && 'md:basis-1/3',
								// flashcard.name.length < 3 && 'basis-full',
								// flashcard.name.length > 5 && flashcard.name.length < 10 && 'basis-full',
								$currentFlashcardTypeStore === 'kanji' && 'basis-1/3'
							)}
						>
							<button
								on:click={() => {
									$currentIndexStore = index;
									embla.scrollTo(index);
								}}
							>
								{flashcard.name}
							</button>
						</Carousel.Item>
					{/each}
				</Carousel.Content>
				<Carousel.Previous />
				<Carousel.Next />
			</Carousel.Root>
		{/if}
	{:else if !isLoading}
		<button
			class="add-form-btn flex h-80 w-1/2 items-center justify-center rounded-xl border-4 border-blue-400 text-center text-xl font-bold text-blue-500 hover:border-blue-500"
			on:click={() => ($clickedAddFlashcardCollection = true)}
		>
			<Plus class="size-10" />
		</button>
	{:else}
		<Skeleton />
	{/if}
</section>
