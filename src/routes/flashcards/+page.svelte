<script lang="ts">
	import TextQuizForm from '$lib/components/forms/TextQuizForm.svelte';
	import FlashcardCollectionForm from '$lib/components/forms/FlashcardCollectionForm.svelte';
	import {
		clickedAddFlashcardCollection,
		maxFlashcards,
		currentFlashcardCollectionId,
		clickedFlashCard,
		clickedEditFlashcard,
		clickedQuizForm
	} from '$lib/utils/stores.js';
	import { superForm } from 'sveltekit-superforms/client';
	import { twSmallScreen } from '$lib/utils/constants';
	import { innerWidthStore } from '$lib/utils/stores';
	import FlashcardCollection from './FlashcardCollection.svelte';
	import { quintOut } from 'svelte/easing';
	import { fly } from 'svelte/transition';
	import { clickOutside } from '$lib/utils/clickOutside';
	import { Dices } from 'lucide-svelte';

	import { writable } from 'svelte/store';
	const skippedFlashcard = writable(false);
	const showCollections = writable(false);

	export let data;

	// console.log(data.flashcardCollections);
	// Client API:
	const { form, errors, constraints, enhance } = superForm(data.form, {
		taintedMessage: null,
		resetForm: true,
		applyAction: true,
		onSubmit: () => {
			$clickedEditFlashcard = false;
			$clickedAddFlashcardCollection = false;
			$clickedFlashCard = false;
		},
		onUpdated: () => {
			if ($errors.name || $errors.description) $clickedAddFlashcardCollection = true;
		}
	});

	// Client API:
	const {
		form: quizForm,
		errors: quizErrors,
		constraints: quizConstraints,
		enhance: quizEnhance
	} = superForm(data.quizForm, {
		taintedMessage: null,
		resetForm: true,
		applyAction: true,
		onSubmit: () => {
			$clickedQuizForm = false;
			$clickedFlashCard = false;
		},
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
</script>

<TextQuizForm
	errors={quizErrors}
	enhance={quizEnhance}
	form={quizForm}
	constraints={quizConstraints}
/>

<FlashcardCollectionForm {enhance} {errors} {form} {constraints} />

<svelte:window bind:innerWidth={$innerWidthStore} />

<section
	use:clickOutside
	on:outsideclick={() => {
		$clickedAddFlashcardCollection = false;
	}}
	class="collection-container flex flex-1 cursor-pointer items-center justify-center pb-20"
>
	{#if $innerWidthStore > twSmallScreen}
		<!-- <button class="mr-60 h-full border-b-2 pb-4 text-4xl font-bold text-gray-300">
			Next Card
		</button> -->
		{#each data.flashcardCollections as card, index}
			<FlashcardCollection
				name={card.name}
				id={card.id}
				description={card.description}
				expand={card.expand}
				{skippedFlashcard}
				{showCollections}
				{index}
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
					expand={card.expand}
					{skippedFlashcard}
					{showCollections}
					{index}
					totalCount={data.flashcardCollections.length}
				/>
			{/each}
		</div>
		<!-- <button class="ml-60 h-full border-b-2 pb-4 text-4xl font-bold text-gray-300">Show Me </button> -->
	{/if}
</section>

{#if $showCollections}
	<div class="fixed top-0 z-[100] h-[100dvh] w-screen bg-black/50 backdrop-blur-md" />
{/if}

{#if $showCollections}
	<div
		use:clickOutside
		on:outsideclick={() => ($showCollections = false)}
		class="
			  add-form-btn scrollable fixed bottom-0 left-1/2 z-[200] flex h-[40dvh] w-full -translate-x-1/2
			  items-center gap-2 overflow-auto rounded-t-2xl bg-white px-2 sm:bottom-0 sm:pb-0 md:max-w-4xl"
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
				{#each collection.expand.flashcardBox as box}
					<a
						href={`/flashcards/${box.id}`}
						class=" flex h-60 flex-none basis-1/2 flex-col items-center justify-between rounded-xl bg-blue-400 text-center text-xl font-bold text-white sm:h-80 sm:basis-1/3"
					>
						<span class="p-4">
							{box.name}
						</span>

						<button
							class=" flex w-full justify-center rounded-t-xl bg-blue-500 p-4"
							on:click|preventDefault={() => {
								$quizForm.flashcardBox = box.id;
								$maxFlashcards = box.count;
								$clickedQuizForm = true;
								$showCollections = false;
							}}
						>
							<Dices />
						</button>
					</a>
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
