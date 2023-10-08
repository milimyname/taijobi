<script lang="ts">
	import { spring, tweened } from 'svelte/motion';

	export let flashcard: {
		meaning: string;
		name: string;
	};
	export let shuffledOptions: string[];
	export let selectAnswer: (e: any, name: string) => void;
	export let ratio: number;

	let tweenedRatio = tweened(0);

	$: $tweenedRatio = ratio;
</script>

<section class="flex h-full w-full flex-col items-center justify-between">
	<div
		class="relative flex h-[504px] w-[354px] items-center justify-center rounded-xl border p-10 shadow-sm sm:h-2/3 sm:w-96"
	>
		<h2 class="text-4xl font-bold">{flashcard.meaning}</h2>
		<div
			class="absolute bottom-0 left-0 h-2 rounded-b-xl bg-black"
			style={`width: ${$tweenedRatio * 100}%`}
		/>
	</div>
	<!-- <h2 class=" text-4xl">{flashcard.name}</h2> -->
	<div class="grid grid-flow-row grid-cols-2 justify-center gap-5 text-4xl">
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
