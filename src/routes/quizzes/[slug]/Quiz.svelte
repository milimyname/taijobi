<script lang="ts">
	import { cn, getFlashcardWidth, getFlashcardHeight } from '$lib/utils';
	import { innerWidthStore, innerHeightStore } from '$lib/utils/stores';
	import { tweened } from 'svelte/motion';

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

<section class="flex h-full flex-col items-center justify-center gap-4 sm:gap-5">
	<div
		style={`height: ${getFlashcardHeight($innerWidthStore, $innerHeightStore)}px;
			width: ${getFlashcardWidth($innerWidthStore)}px`}
		class="relative my-auto flex items-center justify-center rounded-xl border p-10 shadow-sm"
	>
		{#if type === 'name'}
			<h2 class={flashcard.meaning.length > 2 ? 'text-2xl sm:text-4xl' : 'text-5xl sm:text-8xl'}>
				{flashcard.meaning}
			</h2>
		{:else}
			<h2 class={flashcard.name.length > 2 ? 'text-3xl sm:text-4xl' : 'text-4xl  sm:text-8xl'}>
				{flashcard.name}
			</h2>
		{/if}
		<div
			class="absolute bottom-0 left-0 h-2 rounded-b-xl bg-black"
			style={`width: ${$tweenedRatio * 100}%`}
		/>
	</div>
	<div
		style={`width: ${getFlashcardWidth($innerWidthStore)}px;`}
		class={cn(
			'grid grid-cols-2 justify-center gap-2 text-sm sm:gap-5 sm:text-lg',
			type === 'name' && 'text-xl sm:text-4xl'
		)}
	>
		{#each shuffledOptions as option}
			<button
				class="w-full justify-self-center rounded-xl border-2 border-black bg-white p-2 sm:p-4"
				on:click|preventDefault={(e) => {
					selectAnswer(e, option);
				}}
			>
				{option}
			</button>
		{/each}
	</div>
</section>
