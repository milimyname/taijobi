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
		currentBoxId
	} from '$lib/utils/stores.js';
	import { superForm } from 'sveltekit-superforms/client';
	import FlashcardCollection from './FlashcardCollection.svelte';
	import { quintOut } from 'svelte/easing';
	import { fly } from 'svelte/transition';
	import { clickOutside } from '$lib/utils/clickOutside';
	import { Dices, Plus, FolderEdit } from 'lucide-svelte';
	import { goto } from '$app/navigation';
	import { isTouchScreen } from '$lib/utils/actions';
	import { onMount } from 'svelte';
	import { quizSchema, flashcardCollectionSchema } from '$lib/utils/zodSchema';

	import { browser } from '$app/environment';
	import { replaceStateWithQuery } from '$lib/utils';

	export let data;

	$: if (browser && !data.isLoggedIn) {
		const collectionsNames = data.flashcardCollections
			.map((collection: any) => collection.name)
			.join(',');

		replaceStateWithQuery({
			flashcardCollections: collectionsNames
		});
	}

	// Flashcard collection form:
	const superFrmCollection = superForm(data.form, {
		validators: flashcardCollectionSchema,
		taintedMessage: null,
		resetForm: true,
		applyAction: true,
		onSubmit: () => ($clickedAddFlashcardCollection = false),
		onUpdated: ({ form }) => {
			// Keep the form open if there is an error
			if (form.errors.name) $clickedAddFlashcardCollection = true;
		}
	});

	// Quiz form:
	const superFrmQuiz = superForm(data.quizForm, {
		validators: quizSchema,
		taintedMessage: null,
		resetForm: true,
		applyAction: true,
		onSubmit: () => {
			$clickedQuizForm = false;
			$selectedQuizItems = [];
		},
		onUpdated: ({ form }) => {
			// Keep the form open if there is an error
			if (form.errors.name) $clickedQuizForm = true;
		}
	});

	let quizFormData = superFrmQuiz.form;

	// Box form:
	const superFrmBox = superForm(data.boxForm, {
		validators: flashcardCollectionSchema,
		taintedMessage: null,
		resetForm: true,
		applyAction: true,
		onSubmit: () => ($clickedAddFlahcardBox = false),
		onUpdated: ({ form }) => {
			// Keep the form open if there is an error
			if (form.errors.name) $clickedAddFlahcardBox = true;
		}
	});

	let boxFormData = superFrmBox.form;

	// Reactive variable to keep track of visible cards
	let visibleCardsCount =
		data.flashcardCollections.length > 5 ? 5 : data.flashcardCollections.length;

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
			if (visibleCardsCount < data.flashcardCollections.length) visibleCardsCount++;
		}, 100);
	}

	onMount(() => {
		const savedId = localStorage.getItem('currentFlashcardCollectionId');
		if (savedId !== null) $currentFlashcardCollectionId = savedId;

		// Reorder data flashcard collections based on the current flashcard collection id or local storage
		if ($currentFlashcardCollectionId) {
			const currentFlashcardCollectionIndex = data.flashcardCollections.findIndex(
				(collection: { id: string }) => collection.id === $currentFlashcardCollectionId
			);

			const currentFlashcardCollection = data.flashcardCollections.splice(
				currentFlashcardCollectionIndex,
				1
			);

			data.flashcardCollections = [...data.flashcardCollections, ...currentFlashcardCollection];
		}
	});

	$: if ($skippedFlashcard) {
		setTimeout(() => discardCard(), 200);
		$skippedFlashcard = false;
	}

	$: if (data.flashcardCollections.length < 5) visibleCardsCount = data.flashcardCollections.length;
</script>

<FlashcardCollectionForm form={$clickedAddFlahcardBox ? superFrmBox : superFrmCollection} />

<QuizForm form={superFrmQuiz} />

<section class="collection-container flex flex-1 cursor-pointer items-center justify-center pb-20">
	{#if !isTouchScreen()}
		{#each data.flashcardCollections.slice(0, visibleCardsCount) as card, index}
			<FlashcardCollection
				name={card.name}
				id={card.id}
				description={card.description}
				type={card.type}
				{index}
				form={superFrmCollection.form}
				totalCount={visibleCardsCount}
			/>
		{/each}
	{:else}
		<div class="flex cursor-pointer items-center justify-center">
			{#each data.flashcardCollections.slice(0, visibleCardsCount) as card, index}
				<FlashcardCollection
					name={card.name}
					id={card.id}
					description={card.description}
					type={card.type}
					{index}
					form={superFrmCollection.form}
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
						class=" flex h-60 flex-none basis-1/2 flex-col items-center justify-between rounded-xl bg-blue-400 text-center text-xl font-bold text-white sm:h-80 sm:basis-1/3"
					>
						<span class="p-4">
							{box.name}
						</span>

						{#if $flashcardsBoxType !== 'original' || data.isAdmin || box.count > 20}
							<div class="flex w-full justify-around rounded-t-xl bg-blue-500 p-4">
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
