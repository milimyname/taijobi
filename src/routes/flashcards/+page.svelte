<script lang="ts">
	import QuizForm from '$lib/components/forms/quiz-form-ui.svelte';
	import FlashcardCollectionForm from '$lib/components/forms/flashcard-collection-form-ui.svelte';
	import {
		clickedAddFlashcardCollection,
		maxFlashcards,
		currentFlashcardCollectionId,
		clickedAddFlahcardBox,
		clickedEditFlashcard,
		clickedQuizForm,
		flashcardsBoxType,
		skippedFlashcard,
		showCollections,
		selectedQuizItems,
		flashcardBoxes,
		currentAlphabet,
		currentBoxId,
		startRangeQuizForm,
		endRangeQuizForm
	} from '$lib/utils/stores.js';
	import FlashcardCollection from './FlashcardCollection.svelte';
	import { quintOut } from 'svelte/easing';
	import { fly } from 'svelte/transition';
	import { clickOutside } from '$lib/utils/clickOutside';
	import { Dices, Plus, FolderEdit } from 'lucide-svelte';
	import { goto } from '$app/navigation';
	import { isTouchScreen } from '$lib/utils/actions';
	import { onMount } from 'svelte';
	import { quizSchema, flashcardCollectionSchema } from '$lib/utils/zodSchema';
	import { superForm } from 'sveltekit-superforms';
	import { zodClient } from 'sveltekit-superforms/adapters';
	import type { RecordModel } from 'pocketbase';

	export let data;

	// Reactive variable to keep track of visible cards
	let visibleCardsCount =
		data.flashcardCollections.length > 5 ? 5 : data.flashcardCollections.length;

	let savedCollection: RecordModel;

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
			else $clickedAddFlahcardBox = false;
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

	$: if ($skippedFlashcard) {
		setTimeout(() => discardCard(), 200);
		$skippedFlashcard = false;
	}

	// Show the first 5 cards by updatedAt
	$: visibleCards = data.flashcardCollections.slice(0, visibleCardsCount).sort((a, b) => {
		return +new Date(b.updatedAt) - +new Date(a.updatedAt);
	});

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

{#if $showCollections}
	<div class="fixed top-0 z-[60] h-[100dvh] w-screen bg-black/50 backdrop-blur-md" />
{/if}

{#if $showCollections}
	<div
		use:clickOutside={() => {
			$clickedAddFlashcardCollection = false;
			$clickedAddFlahcardBox = false;
			$showCollections = false;
		}}
		class="add-form-btn scrollable fixed bottom-0 left-1/2 z-[101] flex min-h-fit w-full -translate-x-1/2
			 items-center gap-2 overflow-auto rounded-t-2xl bg-white px-2 py-2 sm:bottom-0 md:max-w-4xl"
		transition:fly={{
			delay: 0,
			duration: 500,
			opacity: 0,
			y: 1000,
			easing: quintOut
		}}
	>
		{#if $flashcardsBoxType !== 'original' || data.isAdmin}
			<button
				class="flex h-60 flex-none basis-1/6 flex-col items-center justify-center rounded-xl border-4 border-blue-400 text-center text-xl font-bold text-blue-500 hover:border-blue-500 sm:h-80"
				on:click={() => {
					$clickedAddFlahcardBox = true;
					$clickedEditFlashcard = false;
					$showCollections = false;
				}}
			>
				<Plus class="h-10 w-10" />
			</button>
		{/if}
		{#each data.flashcardCollections as collection}
			{#if collection.id === $currentFlashcardCollectionId && collection.expand}
				{#each collection.expand.flashcardBoxes as box}
					<button
						on:click={() => {
							$showCollections = false;
							// $clickedAddFlashcardCollection = false;
							$clickedAddFlahcardBox = false;

							// Save the type to local storage
							localStorage.setItem('flashcardsBoxType', collection.type);

							goto(`/flashcards/${box.id}`);
						}}
						class="flex h-60 flex-none basis-1/2 flex-col items-center justify-between overflow-y-scroll rounded-xl bg-blue-400 text-center text-white sm:h-80 sm:basis-1/3"
					>
						<div class="space-y-2 p-4">
							<span class="text-xl font-bold">
								{box.name}
							</span>

							<p>
								{box.description}
							</p>
						</div>
						{#if $flashcardsBoxType !== 'original' || data.isAdmin || box.count > 20}
							<div class="sticky bottom-0 flex w-full justify-around rounded-t-xl bg-blue-500 p-4">
								{#if $flashcardsBoxType !== 'original' || data.isAdmin}
									<button
										class="flex w-full justify-center"
										on:click|stopPropagation={() => {
											$clickedEditFlashcard = true;
											$clickedAddFlahcardBox = true;
											$showCollections = false;
											$clickedAddFlashcardCollection = false;
											$flashcardsBoxType = collection.type;
											$maxFlashcards = '' + box.count;

											$flashcardBoxes = [];

											// Save flashcard boxes to store for swapping flashcards later
											collection.expand.flashcardBoxes.forEach((box) => {
												$flashcardBoxes = [
													...$flashcardBoxes,
													{
														id: box.id,
														name: box.name
													}
												];
											});

											// Fill in the form with the current flashcard data
											$boxFormData.name = box.name;
											$boxFormData.description = box.description;
											$boxFormData.id = box.id;
											$currentBoxId = box.id;
										}}
									>
										<FolderEdit />
									</button>
								{/if}

								{#if box.count > 10}
									<button
										class="flex w-full justify-center"
										on:click|stopPropagation={() => {
											$quizFormData.flashcardBox = box.id;
											$quizFormData.name = box.name;
											$maxFlashcards = box.count;
											$clickedQuizForm = true;
											$showCollections = false;
											$clickedAddFlashcardCollection = false;
											$clickedAddFlahcardBox = false;
											$flashcardsBoxType = collection.type;
											$currentAlphabet = '';
										}}
									>
										<Dices />
									</button>
								{/if}
							</div>
						{/if}
					</button>
				{/each}
			{/if}
		{/each}
	</div>
{/if}

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
