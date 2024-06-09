<script lang="ts">
	import QuizForm from '$lib/components/forms/quiz-form-ui.svelte';
	import FlashcardCollectionForm from '$lib/components/forms/flashcard-collection-form-ui.svelte';
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
		newFlashcardBoxId
	} from '$lib/utils/stores.js';
	import FlashcardCollection from './FlashcardCollection.svelte';
	import { goto } from '$app/navigation';
	import { isTouchScreen } from '$lib/utils/actions';
	import { onMount } from 'svelte';
	import { quizSchema, flashcardCollectionSchema } from '$lib/utils/zodSchema';
	import { superForm } from 'sveltekit-superforms';
	import { zodClient } from 'sveltekit-superforms/adapters';
	import type { RecordModel } from 'pocketbase';
	import Collections from './Collections.svelte';
	import { toast } from 'svelte-sonner';

	export let data;

	// Reactive variable to keep track of visible cards
	let visibleCardsCount =
		data.flashcardCollections.length > 5 ? 5 : data.flashcardCollections.length;

	let savedCollection: RecordModel;
	let visibleCards: RecordModel[] = [];

	// Flashcard collection form:
	const superFrmCollection = superForm(data.form, {
		validators: zodClient(flashcardCollectionSchema),
		onUpdated: ({ form }) => {
			// Keep the form open if there is an error
			if (form.errors.name) $clickedAddFlashcardCollection = true;
			else $clickedAddFlashcardCollection = false;

			// Set visible cards count to the total number of flashcard collections
			visibleCardsCount = data.flashcardCollections.length;
		}
	});

	let collectionFormData = superFrmCollection.form;

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
		}
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
				toast.success('Flashcard box added successfully', {
					action: {
						label: 'See it now',
						onClick: () => {
							goto(`/flashcards/${form.data.id}`);
						}
					}
				});
				$newFlashcardBoxId = form.data.id;
			}

			$clickedAddFlahcardBox = false;
		}
	});

	let boxFormData = superFrmBox.form;

	// Function to handle card removal/swipe
	function discardCard() {
		const lastCard = data.flashcardCollections[data.flashcardCollections.length - 1];
		data.flashcardCollections = data.flashcardCollections.slice(
			0,
			data.flashcardCollections.length - 1
		);

		setTimeout(() => {
			data.flashcardCollections = [lastCard, ...data.flashcardCollections];

			// Show one more card when discarding
			if (visibleCardsCount < data.flashcardCollections.length) {
				// console.log('Flashcards box type:', visibleCardsCount, data.flashcardCollections);
				visibleCardsCount = data.flashcardCollections.length;
			}
		}, 100);
	}

	onMount(() => {
		const savedId = localStorage.getItem('currentFlashcardCollectionId');
		if (savedId !== null) $currentFlashcardCollectionId = savedId;
		// Reorder data flashcard collections based on the current flashcard collection id or local storage
		if ($currentFlashcardCollectionId) {
			savedCollection = data.flashcardCollections.find(
				(collection) => collection.id === $currentFlashcardCollectionId
			) as RecordModel;

			visibleCards = [...visibleCards.slice(0, visibleCards.length - 1), savedCollection];
		}
	});

	$: if ($skippedFlashcard) {
		setTimeout(() => discardCard(), 200);
		$skippedFlashcard = false;
	}

	// Show the first 5 cards by updatedAt
	$: visibleCards = data.flashcardCollections.slice(0, visibleCardsCount).sort((a, b) => {
		return +new Date(b.updatedAt) - +new Date(a.updatedAt);
	});
</script>

<FlashcardCollectionForm form={$clickedAddFlahcardBox ? superFrmBox : superFrmCollection} />

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
				form={collectionFormData}
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
					form={collectionFormData}
					totalCount={visibleCardsCount}
				/>
			{/each}
		</div>
	{/if}
</section>

<Collections {data} {boxFormData} {quizFormData} />

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
