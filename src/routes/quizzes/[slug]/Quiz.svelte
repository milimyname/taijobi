<script lang="ts">
	import { spring, tweened } from 'svelte/motion';

	export let flashcard: {
		meaning: string;
		name: string;
	};
	export let shuffledOptions: string[];
	export let selectAnswer: (e: any, name: string) => void;
	export let ratio: number;
	export let type: string;

	let tweenedRatio = tweened(0);

	$: $tweenedRatio = ratio;
</script>

<section class="flex h-screen flex-col items-center justify-between md:gap-20">
	<div
		class="relative flex h-[404px] w-[354px] items-center justify-center rounded-xl border p-10 shadow-sm sm:w-96"
	>
		{#if type === 'name'}
			<h2 class={flashcard.meaning.length > 2 ? 'text-4xl' : 'text-8xl'}>
				{flashcard.meaning}
			</h2>
		{:else}
			<h2 class={flashcard.name.length > 2 ? 'text-4xl' : 'text-8xl'}>
				{flashcard.name}
			</h2>
		{/if}
		<div
			class="absolute bottom-0 left-0 h-2 rounded-b-xl bg-black"
			style={`width: ${$tweenedRatio * 100}%`}
		/>
	</div>
	<div
		class="fixed bottom-5 grid w-[354px] grid-flow-row grid-cols-2 justify-center gap-5 {type ===
		'name'
			? 'text-4xl'
			: 'text-lg'}  sm:w-96"
	>
		{#each shuffledOptions as option}
			<button
				class="w-full rounded-xl border-2 border-black bg-white px-10 py-4 sm:w-40"
				on:click|preventDefault={(e) => {
					selectAnswer(e, option);
				}}
			>
				{option}
			</button>
		{/each}
	</div>
</section>
