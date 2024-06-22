<script lang="ts">
	import { goto } from '$app/navigation';
	import { cn } from '$lib/utils';
	import { clickOutside } from '$lib/utils/clickOutside';
	import {
		showCollections,
		clickedAddFlashcardCollection,
		clickedAddFlahcardBox,
		flashcardsBoxType,
		clickedEditFlashcard,
		currentFlashcardCollectionId,
		maxFlashcards,
		flashcardBoxes,
		clickedQuizForm,
		currentAlphabet,
		currentBoxId,
	} from '$lib/utils/stores';
	import { Dices, Settings, Plus } from 'lucide-svelte';
	import { quintOut } from 'svelte/easing';
	import { fly } from 'svelte/transition';

	export let data;

	export let quizFormData;
	export let boxFormData;

	function goToFlashcardBox(collection: any, box: any) {
		$showCollections = false;
		// $clickedAddFlashcardCollection = false;
		$clickedAddFlahcardBox = false;

		// Save the type to local storage
		localStorage.setItem('flashcardsBoxType', collection.type);

		goto(`/flashcards/${box.id}`);
	}

	function clickOnEdit(collection: any, box: any) {
		$clickedEditFlashcard = true;
		$clickedAddFlahcardBox = true;
		$showCollections = false;
		$clickedAddFlashcardCollection = false;
		$flashcardsBoxType = collection.type;
		$maxFlashcards = '' + box.count;

		$flashcardBoxes = [];

		// Save flashcard boxes to store for swapping flashcards later
		collection.expand.flashcardBoxes.forEach((box: { id: string; name: string }) => {
			$flashcardBoxes = [
				...$flashcardBoxes,
				{
					id: box.id,
					name: box.name,
				},
			];
		});

		// Fill in the form with the current flashcard data
		$boxFormData.name = box.name;
		$boxFormData.description = box.description;
		$boxFormData.id = box.id;
		$currentBoxId = box.id;
		$boxFormData.kanjiCount = box.kanjiCount;
		$boxFormData.quizCount = box.quizCount;
	}

	function clickOnQuizForm(collection: any, box: any) {
		$quizFormData.flashcardBox = box.id;
		$quizFormData.name = box.name;
		$maxFlashcards = box.count;
		$clickedQuizForm = true;
		$showCollections = false;
		$clickedAddFlashcardCollection = false;
		$clickedAddFlahcardBox = false;
		$flashcardsBoxType = collection.type;
		$currentAlphabet = '';
	}
</script>

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
			easing: quintOut,
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
							goToFlashcardBox(collection, box);
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
						<div class="sticky bottom-0 flex w-full justify-around rounded-t-xl bg-blue-500 p-4">
							<button
								class={cn('flex w-full justify-center', box.count < 10 && 'justify-end')}
								on:click|stopPropagation={() => clickOnEdit(collection, box)}
							>
								<Settings />
							</button>

							{#if box.count > 10}
								<button
									class="flex w-full justify-center"
									on:click|stopPropagation={() => {
										clickOnQuizForm(collection, box);
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
	</div>
{/if}
