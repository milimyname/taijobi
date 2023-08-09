<script lang="ts">
	import {
		animateSVG,
		currentLetter,
		hiraganaStore,
		progressSlider,
		katakanaStore,
		currentAlphabet
	} from '$lib/utils/stores';
	import { draw } from 'svelte/transition';
	import { quintOut } from 'svelte/easing';
	import { hiragana } from '$lib/static/hiragana';
	import { katakana } from '$lib/static/katakana';

	export let rotationY: number;

	// Determine which object (hiragana or katakana) to use based on the URL path
	const currentObject = $currentAlphabet === 'hiragana' ? hiragana : katakana;

	// Get current hiragana from store
	$: $currentLetter =
		$currentAlphabet === 'hiragana'
			? $hiraganaStore[$progressSlider - 1]
			: $katakanaStore[$progressSlider - 1];
</script>

<svg
	xmlns="http://www.w3.org/2000/svg"
	viewBox={$currentAlphabet === 'hiragana' ? '0 0 80 87' : '0 0 1024 1024'}
	fill="none"
	class="absolute left-1/2 top-[45%] sm:left-[55%] sm:top-1/2 {rotationY > 30
		? 'hidden'
		: 'block'}  max-w-80 max-h-80 -translate-x-1/2 -translate-y-1/2 opacity-20 sm:-translate-y-1/2"
>
	{#each currentObject[$currentLetter].ds as path, index}
		{#if $animateSVG}
			<path
				d={path}
				stroke="black"
				stroke-width={$currentAlphabet === 'hiragana' ? '3' : '60'}
				stroke-linecap="round"
				stroke-linejoin="round"
				in:draw={{ duration: 1000, delay: index * 1000, easing: quintOut }}
			/>
		{/if}
	{/each}
</svg>
