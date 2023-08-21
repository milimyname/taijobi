<script lang="ts">
	import { kanjiStore } from '$lib/utils/stores';
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
	import { kanji } from '$lib/static/kanji';
	import { getRandomNumber } from '$lib/utils/actions.js';

	export let rotationY: number;

	// Set the correct viewBox for the SVG
	let viewBox: string;

	// Determine which object (hiragana, katakana, kanji) to use based on the URL path
	let currentObject: any;

	$: switch ($currentAlphabet) {
		case 'katakana':
			$currentLetter = $katakanaStore[$progressSlider - 1];
			viewBox = '0 0 1024 1024';
			currentObject = katakana;
			break;
		case 'kanji':
			$currentLetter = $kanjiStore[$progressSlider - 1];
			viewBox = '0 0 109 109';
			currentObject = kanji;
			break;
		default:
			$currentLetter = $hiraganaStore[$progressSlider - 1];
			viewBox = '0 0 80 87';
			currentObject = hiragana;
	}
</script>

<svg
	xmlns="http://www.w3.org/2000/svg"
	{viewBox}
	fill="none"
	class="absolute left-1/2 top-[45%] sm:left-[55%] sm:top-1/2 {rotationY > 5
		? 'hidden'
		: 'block'}  max-w-80 max-h-80 -translate-x-1/2 -translate-y-1/2 opacity-20 sm:-translate-y-1/2"
>
	{#each currentObject[$currentLetter].ds as path, index}
		{#if $animateSVG}
			<path
				d={path}
				stroke="black"
				stroke-width={$currentAlphabet === 'katakana' ? '30' : '3'}
				stroke-linecap="round"
				stroke-linejoin="round"
				in:draw={{ duration: 1000, delay: index * 1000, easing: quintOut }}
			/>
		{/if}
	{/each}
</svg>
