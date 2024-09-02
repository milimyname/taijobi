<script lang="ts">
	import QuizForm from '$lib/components/forms/quiz-form-ui.svelte';
	import FlashcardCollectionUI from '$lib/components/forms/flashcard-collection-form-ui.svelte';
	import {
		clickedAddFlashcardCollection,
		currentFlashcardCollectionId,
		clickedAddFlahcardBox,
		clickedEditFlashcard,
		clickedQuizForm,
		skippedFlashcard,
		selectedQuizItems,
		startRangeQuizForm,
		endRangeQuizForm,
		newFlashcardBoxId,
	} from '$lib/utils/stores.js';
	import FlashcardCollection from './FlashcardCollection.svelte';
	import { goto } from '$app/navigation';
	import { isTouchScreen } from '$lib/utils/actions';
	import { onMount, setContext } from 'svelte';
	import { quizSchema, flashcardCollectionSchema } from '$lib/utils/zodSchema';
	import { superForm } from 'sveltekit-superforms';
	import { zodClient } from 'sveltekit-superforms/adapters';
	import type { RecordModel } from 'pocketbase';
	import Collections from './Collections.svelte';
	import { toast } from 'svelte-sonner';

	export let data;

	// Reactive variable to keep track of visible cards
	let visibleCardsCount = data.flashcardCollections.length || 5;
	let savedCollection: RecordModel;
	let visibleCards: RecordModel[] = [];

	// Flashcard collection form:
	const superFrmCollection = superForm(data.form, {
		validators: zodClient(flashcardCollectionSchema),
		onUpdated: ({ form }) => {
			// Set visible cards count to the total number of flashcard collections
			if ($clickedEditFlashcard && !form.data.actionForm) {
				visibleCardsCount = data.flashcardCollections.length;
				// Remove the current flashcard collection from the visible cards
				data.flashcardCollections = data.flashcardCollections.filter(
					(collection) =>
						collection.id !== form.data.id || collection.id !== $currentFlashcardCollectionId,
				);
			}

			// Put new added flashcard collection to the top of the list
			if ($clickedAddFlashcardCollection && !$clickedEditFlashcard) {
				localStorage.setItem('currentFlashcardCollectionId', form.data.id as string);
				visibleCards = [...visibleCards, form.data];
				visibleCardsCount = data.flashcardCollections.length;
			}

			// Keep the form open if there is an error
			if (form.errors.name) $clickedAddFlashcardCollection = true;
			else $clickedAddFlashcardCollection = false;

			$currentFlashcardCollectionId = form.data.id as string;
		},
	});

	setContext('collectionForm', superFrmCollection);

	// Quiz form:
	const superFrmQuiz = superForm(data.quizForm, {
		validators: zodClient(quizSchema),
		onError: (error) => {
			if (error) $clickedQuizForm = true;
		},
		onSubmit: ({ formData }) => {
			// !IMPORTANT:
			// It is a workaround since it cannot capture the form data from nested drawer/dialog components
			formData.set('startCount', $startRangeQuizForm);
			formData.set('maxCount', $endRangeQuizForm);
		},
		onUpdated: ({ form }) => {
			if (!form.valid) return;

			$clickedQuizForm = false;
			$selectedQuizItems = [];
			goto(`/games/quizzes/${form.data.id}`);
		},
	});

	let quizFormData = superFrmQuiz.form;

	// Box form:
	const superFrmBox = superForm(data.boxForm, {
		validators: zodClient(flashcardCollectionSchema),
		onUpdated: ({ form }) => {
			// Keep the form open if there is an error
			if (form.errors.name) $clickedAddFlahcardBox = true;

			// Send a toast message when a new flashcard box is added
			if ($clickedAddFlahcardBox && !$clickedEditFlashcard) {
				toast('Flashcard box added successfully', {
					action: {
						label: 'See it now',
						onClick: () => {
							goto(`/flashcards/${form.data.id}`);
						},
					},
				});
				$newFlashcardBoxId = form.data.id as string;
			}

			$clickedAddFlahcardBox = false;
		},
	});

	setContext('boxForm', superFrmBox);

	// Function to handle card removal/swipe
	function discardCard(timeout = 100) {
		// Get the last card from the data flashcard collections
		const lastCard = data.flashcardCollections[data.flashcardCollections.length - 1];

		// Remove the last card from the visibleCards
		data.flashcardCollections = data.flashcardCollections.filter((card) => card.id !== lastCard.id);

		// Get the next collection id to show
		const nextCollectionId = visibleCards.at(-2)?.id;

		// Set the next collection id to the local storage and current flashcard collection id
		if (nextCollectionId) {
			localStorage.setItem('currentFlashcardCollectionId', nextCollectionId);
			$currentFlashcardCollectionId = nextCollectionId;
		} else {
			localStorage.setItem('currentFlashcardCollectionId', lastCard.id);
			$currentFlashcardCollectionId = lastCard.id;
		}

		setTimeout(() => {
			data.flashcardCollections = [lastCard, ...data.flashcardCollections];

			// Show one more card when discarding
			visibleCardsCount = data.flashcardCollections.length;
		}, timeout);
	}

	// Function to update visible cards
	function updateVisibleCards() {
		visibleCards = data.flashcardCollections.slice(0, visibleCardsCount).sort((a, b) => {
			return +new Date(b.updatedAt) - +new Date(a.updatedAt);
		});
	}

	onMount(() => {
		const savedId = localStorage.getItem('currentFlashcardCollectionId');
		if (savedId !== null) $currentFlashcardCollectionId = savedId;
		// Reorder data flashcard collections based on the current flashcard collection id or local storage
		if ($currentFlashcardCollectionId) {
			savedCollection = data.flashcardCollections.find(
				(collection) => collection.id === $currentFlashcardCollectionId,
			) as RecordModel;

			// Ensure visible cards are updated
			if (savedCollection)
				data.flashcardCollections = [
					...data.flashcardCollections.filter((card) => card.id !== savedCollection?.id),
					savedCollection,
				];
		}

		// if there is undefined in visibleCards, remove it and remove local storage
		if (visibleCards.includes(undefined) || visibleCards.includes(null)) {
			visibleCards = visibleCards.filter((card) => card != null);
			localStorage.removeItem('currentFlashcardCollectionId');
		}
	});

	$: if ($skippedFlashcard) {
		setTimeout(discardCard, 200);
		$skippedFlashcard = false;
	}

	// Use the updateVisibleCards function to keep visibleCards reactive
	$: if (data.flashcardCollections) updateVisibleCards();
</script>

<FlashcardCollectionUI form={$clickedAddFlahcardBox ? superFrmBox : superFrmCollection} />

<QuizForm form={superFrmQuiz} />

<section class="collection-container flex flex-1 cursor-pointer items-center justify-center pb-20">
	{#if !isTouchScreen()}
		{#each visibleCards as card, index}
			<FlashcardCollection
				name={card.name}
				id={card.id}
				description={card.description}
				type={card.type}
				{index}
				totalCount={visibleCardsCount}
			/>
		{/each}
	{:else}
		<div class="flex cursor-pointer items-center justify-center">
			{#each visibleCards as card, index}
				<FlashcardCollection
					name={card.name}
					id={card.id}
					description={card.description}
					type={card.type}
					{index}
					totalCount={visibleCardsCount}
				/>
			{/each}
		</div>
	{/if}
</section>

<Collections {data} {quizFormData} />

<style>
	.collection-container {
		perspective: 1000px;
		height: 100dvh;
	}

	.scrollable {
		overflow-y: scroll; /* or 'auto' */
		-webkit-overflow-scrolling: touch;
	}
</style>
