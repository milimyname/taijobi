<script lang="ts">
	import TextQuizForm from '$lib/components/forms/TextQuizForm.svelte';
	import FlashcardCollectionForm from '$lib/components/forms/FlashcardCollectionForm.svelte';
	import {
		clickedAddFlashcardCollection,
		maxFlashcards,
		currentFlashcardCollectionId,
		clickedAddFlahcardBox,
		clickedEditFlashcard,
		clickedQuizForm,
		flashcardsBoxType,
		skippedFlashcard,
		showCollections
	} from '$lib/utils/stores.js';
	import { superForm } from 'sveltekit-superforms/client';
	import { innerWidthStore } from '$lib/utils/stores';
	import FlashcardCollection from './FlashcardCollection.svelte';
	import { quintOut } from 'svelte/easing';
	import { fly } from 'svelte/transition';
	import { clickOutside } from '$lib/utils/clickOutside';
	import { Dices, Plus, FolderEdit } from 'lucide-svelte';
	import { goto } from '$app/navigation';

	export let data;

	// Flashcard collection form:
	const { form, errors, constraints, enhance } = superForm(data.form, {
		taintedMessage: null,
		resetForm: true,
		applyAction: true,
		onSubmit: () => ($clickedAddFlashcardCollection = false),
		onUpdated: () => {
			if ($errors.name || $errors.description) $clickedAddFlashcardCollection = true;
		}
	});

	// Quiz form:
	const {
		form: quizForm,
		errors: quizErrors,
		constraints: quizConstraints,
		enhance: quizEnhance
	} = superForm(data.quizForm, {
		taintedMessage: null,
		resetForm: true,
		applyAction: true,
		onSubmit: () => ($clickedQuizForm = false),
		onUpdated: () => {
			if ($errors.name || $errors.description) $clickedQuizForm = true;
		}
	});

	// Box form:
	const {
		form: boxForm,
		errors: boxErrors,
		constraints: boxConstraints,
		enhance: boxEnhance
	} = superForm(data.boxForm, {
		taintedMessage: null,
		resetForm: true,
		applyAction: true,
		onSubmit: () => ($clickedAddFlahcardBox = false),
		onUpdated: () => {
			if ($errors.name || $errors.description) $clickedQuizForm = true;
		}
	});

	// Function to handle card removal/swipe
	function discardCard() {
		if (data.flashcardCollections.length > 0) {
			const lastCard = data.flashcardCollections[data.flashcardCollections.length - 1];
			data.flashcardCollections = data.flashcardCollections.slice(
				0,
				data.flashcardCollections.length - 1
			);

			setTimeout(() => {
				data.flashcardCollections = [lastCard, ...data.flashcardCollections];
			}, 100);
		}
	}

	$: if ($skippedFlashcard) {
		setTimeout(() => discardCard(), 200);
		$skippedFlashcard = false;
	}

	// Function to handle whether the device is touch screen
	function isTouchScreen() {
		if (typeof window === 'undefined') return false;

		return 'ontouchstart' in window || navigator.maxTouchPoints > 0 || navigator.maxTouchPoints > 0;
	}
</script>

<svelte:window bind:innerWidth={$innerWidthStore} />

{#if $clickedAddFlashcardCollection}
	<FlashcardCollectionForm {enhance} {errors} {form} {constraints} />
{/if}

{#if $clickedAddFlahcardBox}
	<FlashcardCollectionForm
		errors={boxErrors}
		enhance={boxEnhance}
		form={boxForm}
		constraints={boxConstraints}
	/>
{/if}

<TextQuizForm
	errors={quizErrors}
	enhance={quizEnhance}
	form={quizForm}
	constraints={quizConstraints}
/>

<section
	use:clickOutside={() => {
		$clickedAddFlashcardCollection = false;
		$clickedEditFlashcard = false;

		// Clear the form
		$form.name = '';
		$form.description = '';
		$form.id = '';
	}}
	class="collection-container flex flex-1 cursor-pointer items-center justify-center pb-20"
>
	{#if !isTouchScreen()}
		<!-- <button class="mr-60 h-full border-b-2 pb-4 text-4xl font-bold text-gray-300">
			Next Card
		</button> -->
		{#each data.flashcardCollections as card, index}
			<FlashcardCollection
				name={card.name}
				id={card.id}
				description={card.description}
				type={card.type}
				{index}
				{form}
				totalCount={data.flashcardCollections.length}
			/>
		{/each}
		<!-- <button class="ml-60 h-full border-b-2 pb-4 text-4xl font-bold text-gray-300">Show Me </button> -->
	{:else}
		<!-- <button class="mr-60 h-full border-b-2 pb-4 text-4xl font-bold text-gray-300">
			Next Card
		</button> -->
		<div class="flex cursor-pointer items-center justify-center">
			{#each data.flashcardCollections as card, index}
				<FlashcardCollection
					name={card.name}
					id={card.id}
					description={card.description}
					type={card.type}
					{index}
					{form}
					totalCount={data.flashcardCollections.length}
				/>
			{/each}
		</div>
		<!-- <button class="ml-60 h-full border-b-2 pb-4 text-4xl font-bold text-gray-300">Show Me </button> -->
	{/if}
</section>

{#if $showCollections}
	<div
		use:clickOutside={() => {
			$clickedAddFlashcardCollection = false;
			$clickedAddFlahcardBox = false;
			$showCollections = false;
		}}
		class="
			  add-form-btn scrollable fixed bottom-0 left-1/2 z-[1001] flex min-h-fit w-full -translate-x-1/2
			 items-center gap-2 overflow-auto rounded-t-2xl bg-white px-2 py-2 sm:bottom-0 md:max-w-4xl"
		transition:fly={{
			delay: 0,
			duration: 500,
			opacity: 0,
			y: 1000,
			easing: quintOut
		}}
	>
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
						data-sveltekit-preload-data
						class=" flex h-60 flex-none basis-1/2 flex-col items-center justify-between rounded-xl bg-blue-400 text-center text-xl font-bold text-white sm:h-80 sm:basis-1/3"
					>
						<span class="p-4">
							{box.name}
						</span>

						<div class="flex w-full justify-around rounded-t-xl bg-blue-500 p-4">
							{#if $flashcardsBoxType !== 'original' || data.isAdmin}
								<button
									on:click|stopPropagation={() => {
										$clickedEditFlashcard = true;
										$clickedAddFlahcardBox = true;
										$showCollections = false;
										$clickedAddFlashcardCollection = false;
										$flashcardsBoxType = collection.type;

										// Fill in the form with the current flashcard data
										$boxForm.name = box.name;
										$boxForm.description = box.description;
										$boxForm.id = box.id;
									}}
								>
									<FolderEdit />
								</button>
							{/if}

							{#if box.count > 20}
								<button
									on:click|stopPropagation={() => {
										$quizForm.flashcardBox = box.id;
										$maxFlashcards = box.count;
										$clickedQuizForm = true;
										$showCollections = false;
										$clickedAddFlashcardCollection = false;
										$clickedAddFlahcardBox = false;
										$flashcardsBoxType = collection.type;
									}}
								>
									<Dices />
								</button>
							{/if}
						</div>
					</button>
				{/each}
			{/if}
		{/each}

		{#if $flashcardsBoxType !== 'original' || data.isAdmin}
			<button
				class="flex h-60 flex-none basis-1/4 flex-col items-center justify-center rounded-xl border-4 border-blue-400 text-center text-xl font-bold text-blue-500 hover:border-blue-500 sm:h-80"
				on:click={() => {
					$clickedAddFlahcardBox = true;
					$showCollections = false;
				}}
			>
				<Plus class="h-10 w-10" />
			</button>
		{/if}
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
