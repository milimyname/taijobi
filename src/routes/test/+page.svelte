<script lang="ts">
	import Card from './Card.svelte';

	const range = (length: number) => [...Array(length).keys()];

	let cards = range(5).map((_value, index) => ({
		id: index, // Ideally, use a unique ID generator
		value: index // Replace with actual card content
	}));

	// Function to handle card removal/swipe
	function discardCard() {
		cards = cards.slice(1);
	}
</script>

<div class="flex h-screen w-screen items-center justify-center">
	<div
		class=" relative flex h-[40rem] w-[40rem] items-center justify-center overflow-hidden border-2 border-black"
	>
		{#each cards as card, index}
			<Card value={card.value} {index} totalCount={cards.length} on:click={discardCard} />
		{/each}
	</div>
</div>

<input type="range" min="0" max="100"  />
