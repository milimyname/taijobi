<script lang="ts">
	import Card from './Card.svelte';
	import { writable } from 'svelte/store';

	let clickedCard = writable(false);

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

	$: if ($clickedCard) {
		setTimeout(() => discardCard(), 200);
		$clickedCard = false;
	}
</script>

<div class="card-container flex flex-1 cursor-pointer items-center justify-center">
	<button class="mr-60 h-full border-b-2 pb-4 text-4xl font-bold text-gray-300"> Next Card </button>
	<div class="flex cursor-pointer items-center justify-center">
		{#each cards as card, index}
			<Card value={card.value} {index} {clickedCard} totalCount={cards.length} />
		{/each}
	</div>
	<button class="ml-60 h-full border-b-2 pb-4 text-4xl font-bold text-gray-300">Show Me </button>
</div>

<style>
	.card-container {
		perspective: 1000px;
		height: 100dvh;
	}
</style>
