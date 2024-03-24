<script lang="ts">
	import {
		selectQuizItemsForm,
		clickedKanjiForm,
		selectedQuizItems,
		clickedEditFlashcard,
		clickedAddFlahcardBox,
		swapFlashcards,
		flashcardBoxes
	} from '$lib/utils/stores';
	import { kanji } from '$lib/static/kanji';
	import { page } from '$app/stores';
	import { pocketbase } from '$lib/utils/pocketbase';
	import { invalidateAll } from '$app/navigation';
	import { Button } from '$lib/components/ui/button';

	export let flashcardBox: string;

	let flashcards: {
		name: string;
		meaning: string;
		id: string;
	}[] = [];

	let selectedFlashcardBox: string;

	async function getFlashcards() {
		flashcards = await pocketbase.collection('flashcard').getFullList({
			filter: `flashcardBox = "${flashcardBox}"`,
			fields: 'name,meaning,id'
		});
	}

	async function onSwapFlashcards() {
		// Swap the flashcards
		$selectedQuizItems.forEach(async (item) => {
			const [id] = item.split('=');
			await pocketbase.collection('flashcard').update(id, {
				flashcardBox: selectedFlashcardBox
			});
		});

		// Close the form
		$swapFlashcards = false;
		$selectQuizItemsForm = false;
		$clickedAddFlahcardBox = false;
		$clickedEditFlashcard = false;
		$selectedQuizItems = [];

		invalidateAll();
	}

	$: if (($selectQuizItemsForm || $swapFlashcards) && !$page.url.pathname.includes('kanji'))
		getFlashcards();
</script>

<div class="select-quiz-data flex flex-1 flex-col overflow-y-auto">
	<h4 class="px-5 py-2 text-2xl">
		{$swapFlashcards ? 'Swap Flashcards' : 'Select Quiz Items'}
	</h4>

	{#if $clickedKanjiForm && $page.url.pathname.includes('kanji')}
		<ul class="grid grid-cols-2 gap-3 px-5 xm:grid-cols-4 sm:grid-cols-8">
			{#each Object.keys(kanji) as letter, i}
				<li class="flex flex-col justify-between">
					<button
						class="{$selectedQuizItems.includes(letter)
							? 'bg-black text-white hover:bg-gray-700'
							: 'border-2 border-black bg-white text-black hover:bg-gray-200'}
                         relative rounded-md px-4 py-2 font-medium shadow-lg transition duration-200 visited:-translate-x-4 active:translate-y-1 active:shadow-sm"
						on:click|preventDefault={() => {
							// Remove the letter if it's already selected
							if ($selectedQuizItems.includes(letter)) {
								$selectedQuizItems = $selectedQuizItems.filter((item) => item !== letter);
								return;
							}

							$selectedQuizItems = [...$selectedQuizItems, letter];
						}}
					>
						<span class="absolute left-1 top-0 text-[10px]">{i + 1}</span>
						<span>{letter}</span>
					</button>
				</li>
			{/each}
		</ul>
	{:else}
		<ul class="mb-auto grid grid-cols-2 gap-3 px-5 xm:grid-cols-4 sm:grid-cols-8">
			{#each flashcards as flashcard, i}
				{@const formattedItem = $swapFlashcards
					? flashcard.id + '=' + flashcard.meaning
					: '---' + flashcard.name + '=' + flashcard.meaning}
				<li>
					<button
						class=" {$selectedQuizItems.includes(formattedItem)
							? 'bg-black text-white hover:bg-gray-700'
							: 'border-2 border-black bg-white text-black hover:bg-gray-200'}
                         relative h-full rounded-md px-4 py-2 font-medium shadow-lg transition duration-200 visited:-translate-x-4 active:translate-y-1 active:shadow-sm"
						on:click|preventDefault={() => {
							// Remove the letter if it's already selected
							if ($selectedQuizItems.includes(formattedItem)) {
								$selectedQuizItems = $selectedQuizItems.filter((item) => item !== formattedItem);
								return;
							}

							$selectedQuizItems = [...$selectedQuizItems, formattedItem];
						}}
					>
						<span class="absolute left-1 top-0 text-[10px]">{i + 1}</span>
						<span>{flashcard.name}</span>
					</button>
				</li>
			{/each}
		</ul>
	{/if}
	<div
		class="sticky bottom-0 z-40 flex w-full items-center justify-between gap-2 rounded-b-md bg-white p-5 shadow-profile sm:bottom-0"
	>
		<slot />

		{#if $selectedQuizItems.length < 10 && $selectedQuizItems.length > 0 && !$swapFlashcards}
			<p class="px-5 text-sm font-bold text-red-400">
				At least 10 items ({$selectedQuizItems.length})
			</p>
		{/if}

		{#if $swapFlashcards}
			<div class="flex items-center gap-3 sm:gap-5">
				<div>
					<span>Move to</span>
					<select
						bind:value={selectedFlashcardBox}
						class="border-hidden bg-none pr-3 text-center font-bold outline-none focus:border-transparent focus:ring-0"
					>
						{#each $flashcardBoxes as box}
							{#if box.id !== flashcardBox}
								<option value={box.id}>{box.name}</option>
							{/if}
						{/each}
					</select>
					<span>box</span>
				</div>
				<Button on:click={onSwapFlashcards}>Submit</Button>
			</div>
		{:else}
			<Button
				disabled={$selectedQuizItems.length < 10}
				on:click={() => ($selectQuizItemsForm = false)}
			>
				{#if $selectedQuizItems.length < 10}
					Not yet
				{:else}
					Select
				{/if}
			</Button>
		{/if}
	</div>
</div>
