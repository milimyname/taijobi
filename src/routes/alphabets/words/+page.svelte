<script lang="ts">
	import { animateSVG, currentLetter, hiraganaStore, progressSlider } from '$lib/utils/stores';
	import { draw } from 'svelte/transition';
	import { quintOut } from 'svelte/easing';
	import { katakana } from '$lib/static/katakana';
	export let rotationY: number;

	// Get current hiragana from store
	$: $currentLetter = $hiraganaStore[$progressSlider - 1];
</script>

<svg
	xmlns="http://www.w3.org/2000/svg"
	viewBox="0 0 1024 1024"
	fill="none"
	class="absolute left-1/2 top-[45%] sm:left-[55%] sm:top-1/2 {rotationY > 30
		? 'hidden'
		: 'block'}  max-w-80 max-h-80 -translate-x-1/2 -translate-y-1/2 opacity-20 sm:-translate-y-1/2"
>
	{#each katakana['ヨ'].ds as path, index}
		{#if $animateSVG}
			<path
				d={path}
				stroke="black"
				stroke-width="60"
				stroke-linecap="round"
				stroke-linejoin="round"
				transition:draw={{ duration: 1000, delay: index * 1000, easing: quintOut }}
			/>
		{/if}
	{/each}
</svg>

<button on:click={() => ($animateSVG = !$animateSVG)}>Click</button>
