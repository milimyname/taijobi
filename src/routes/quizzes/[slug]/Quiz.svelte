<script lang="ts">
	export let flashcard: {
		name: string;
		meaning: string;
	};
	export let shuffledOptions: string[];
	export let selectAnswer: (e: any, name: string) => void;
</script>

<section class="flex h-full w-full flex-col items-center justify-between">
	<h2 class="mt-52 text-4xl font-bold">{flashcard.meaning}</h2>
	<div class="grid w-full grid-flow-row grid-cols-2 justify-center gap-5 text-4xl">
		{#each shuffledOptions as option}
			<button
				class="w-full rounded-xl border-2 border-black px-10 py-4 sm:w-40"
				on:click|preventDefault={(e) => {
					selectAnswer(e, option);
				}}
			>
				{option}
			</button>
		{/each}
	</div>
</section>
