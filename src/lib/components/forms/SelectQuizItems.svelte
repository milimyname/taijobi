<script lang="ts">
	import {
		selectQuizItemsForm,
		clickedKanjiForm,
		selectedQuizItems,
		swapFlashcards,
		flashcardBoxes
	} from '$lib/utils/stores';
	import { fly } from 'svelte/transition';
	import { quintOut } from 'svelte/easing';
	import { clickOutside } from '$lib/utils/clickOutside';
	import { kanji } from '$lib/static/kanji';
	import { page } from '$app/stores';
	import { pocketbase } from '$lib/utils/pocketbase';
	import { invalidateAll } from '$app/navigation';

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
			const [id, meaning] = item.split('=');
			await pocketbase.collection('flashcard').update(id, {
				flashcardBox: selectedFlashcardBox
			});
		});

		// Close the form
		$swapFlashcards = false;
		$selectedQuizItems = [];

		invalidateAll();
	}

	$: if (($selectQuizItemsForm || $swapFlashcards) && !$page.url.pathname.includes('kanji'))
		getFlashcards();
</script>

<div
	use:clickOutside={() => {
		$selectQuizItemsForm = false;
		$swapFlashcards = false;

		$selectedQuizItems = [];
	}}
	class="add-form-btn fixed -bottom-5 z-[1020] flex
     {$clickedKanjiForm ? 'h-[90dvh] sm:h-5/6' : 'h-[80dvh] sm:h-3/4'} 
    w-full flex-col gap-4 overflow-y-scroll rounded-t-2xl bg-white sm:bottom-0 md:max-w-4xl"
	transition:fly={{
		delay: 0,
		duration: 1000,
		opacity: 0,
		y: 1000,
		easing: quintOut
	}}
>
	<h4 class="text-2xl px-5 pt-5">
		{$swapFlashcards ? 'Swap Flashcards' : 'Select Quiz Items'}
	</h4>

	{#if $clickedKanjiForm && $page.url.pathname.includes('kanji')}
		<ul class="grid grid-cols-2 xm:grid-cols-4 sm:grid-cols-8 gap-3 px-5">
			{#each Object.keys(kanji) as letter, i}
				<li class="flex flex-col justify-between">
					<button
						class=" {$selectedQuizItems.includes(letter)
							? 'bg-black text-white hover:bg-gray-700 '
							: 'bg-white  text-black border-2 border-black hover:bg-gray-200  '}
                         rounded-md px-4 py-2 relative font-medium shadow-lg transition duration-200 visited:-translate-x-4 active:translate-y-1 active:shadow-sm"
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
		<ul class="grid grid-cols-2 xm:grid-cols-4 sm:grid-cols-8 gap-3 px-5 mb-auto">
			{#each flashcards as flashcard, i}
				{@const formattedItem = $swapFlashcards
					? flashcard.id + '=' + flashcard.meaning
					: '---' + flashcard.name + '=' + flashcard.meaning}
				<li class="self-stretch flex flex-col justify-between">
					<button
						class=" {$selectedQuizItems.includes(formattedItem)
							? 'bg-black text-white hover:bg-gray-700 '
							: 'bg-white  text-black border-2  border-black hover:bg-gray-200  '}
                         rounded-md px-4 py-2 relative grow font-medium shadow-lg transition duration-200 visited:-translate-x-4 active:translate-y-1 active:shadow-sm"
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
		class="sticky bottom-5 sm:bottom-0 z-40 flex gap-2 w-full bg-white justify-between items-center shadow-profile p-5"
	>
		<button
			on:click={() => {
				$selectQuizItemsForm = false;
				$swapFlashcards = false;
				$selectedQuizItems = [];
			}}
			class="text-md rounded-md border-2 border-black px-4 py-2 font-medium text-black shadow-lg transition duration-200 visited:-translate-x-4 active:translate-y-1 active:shadow-sm"
		>
			Cancel
		</button>
		{#if $selectedQuizItems.length < 20 && $selectedQuizItems.length > 0 && !$swapFlashcards}
			<p class="px-5 text-sm font-bold text-red-400">
				At least 20 items ({$selectedQuizItems.length})
			</p>
		{/if}

		{#if $swapFlashcards}
			<div class="flex gap-2 sm:gap-5">
				<div>
					<span>Move to</span>
					<select
						bind:value={selectedFlashcardBox}
						class="border-hidden font-bold bg-none pr-3 text-center outline-none focus:border-transparent focus:ring-0"
					>
						{#each $flashcardBoxes as box}
							{#if box.id !== flashcardBox}
								<option value={box.id}>{box.name}</option>
							{/if}
						{/each}
					</select>
					<span>box</span>
				</div>
				<button
					on:click={onSwapFlashcards}
					class="text-md rounded-md bg-black px-4 py-2 font-medium text-white shadow-lg transition duration-200 visited:-translate-x-4 hover:bg-gray-700 active:translate-y-1 active:shadow-sm"
				>
					Submit
				</button>
			</div>
		{:else}
			<button
				disabled={$selectedQuizItems.length < 20}
				on:click={() => ($selectQuizItemsForm = false)}
				class="text-md rounded-md bg-black px-4 py-2 {$selectedQuizItems.length < 20 &&
					'bg-black/50'} font-medium text-white shadow-lg transition duration-200 visited:-translate-x-4 hover:bg-gray-700 active:translate-y-1 active:shadow-sm"
			>
				{#if $selectedQuizItems.length < 20}
					Not yet
				{:else}
					Select
				{/if}
			</button>
		{/if}
	</div>
</div>
