<script lang="ts">
	import { IS_DESKTOP } from '$lib/utils/constants';
	import { innerWidthStore } from '$lib/utils/stores';
	import Card from './Card.svelte';
	import { quintOut } from 'svelte/easing';
	import { fly } from 'svelte/transition';
	import { clickOutside } from '$lib/utils/clickOutside';

	import { writable } from 'svelte/store';
	const skippedFlashcard = writable(false);
	const showCollections = writable(false);

	let cards = [
		{
			id: 0,
			value: 0
		},
		{
			id: 1,

			value: 1
		},
		{
			id: 2,
			value: 2
		},
		{
			id: 3,
			value: 3
		}
	];

	// Function to handle card removal/swipe
	function discardCard() {
		if (cards.length > 0) {
			const lastCard = cards[cards.length - 1];
			cards = cards.slice(0, cards.length - 1);

			setTimeout(() => {
				cards = [lastCard, ...cards];
			}, 100);
		}
	}

	$: if ($skippedFlashcard) {
		setTimeout(() => discardCard(), 200);
		$skippedFlashcard = false;
	}
</script>

<svelte:window bind:innerWidth={$innerWidthStore} />

{#if $innerWidthStore > IS_DESKTOP}
	<div class="card-container t flex flex-1 cursor-pointer items-center justify-center">
		<button class="mr-60 h-full border-b-2 pb-4 text-4xl font-bold text-gray-300">
			Next Card
		</button>
		{#each cards as card, index}
			<Card
				value={card.value}
				{skippedFlashcard}
				{showCollections}
				{index}
				totalCount={cards.length}
			/>
		{/each}
		<button class="ml-60 h-full border-b-2 pb-4 text-4xl font-bold text-gray-300">Show Me </button>
	</div>
{:else}
	<div class="card-container flex flex-1 cursor-pointer items-center justify-center">
		<button class="mr-60 h-full border-b-2 pb-4 text-4xl font-bold text-gray-300">
			Next Card
		</button>
		<div class="flex cursor-pointer items-center justify-center">
			{#each cards as card, index}
				<Card
					value={card.value}
					{skippedFlashcard}
					{showCollections}
					{index}
					totalCount={cards.length}
				/>
			{/each}
		</div>
		<button class="ml-60 h-full border-b-2 pb-4 text-4xl font-bold text-gray-300">Show Me </button>
	</div>
{/if}

{#if $showCollections}
	<div class="fixed top-0 z-[100] h-screen w-screen bg-black/50 backdrop-blur-md" />
{/if}

{#if $showCollections}
	<div
		use:clickOutside={() => ($showCollections = false)}
		on:scroll|preventDefault
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
		{#each cards as d}
			<a
				href="/daasd"
				class=" h-60 flex-none basis-1/2 rounded-xl bg-blue-400 p-4 text-center text-white sm:h-80 sm:basis-1/3"
			>
				<p class="text-xl font-bold">Flashcards</p>
			</a>
		{/each}
	</div>
{/if}

<style>
	.card-container {
		perspective: 1000px;
		height: 100dvh;
	}

	.scrollable {
		overflow-y: scroll; /* or 'auto' */
		-webkit-overflow-scrolling: touch;
	}
</style>
