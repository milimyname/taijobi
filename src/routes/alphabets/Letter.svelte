<script lang="ts">
	import { kanjiStore } from '$lib/utils/stores';
	import {
		animateSVG,
		currentLetter,
		hiraganaStore,
		progressSlider,
		katakanaStore,
		currentAlphabet,
		selectedKanjiGrade,
		kanjiLength,
		kanjiWidthMulitplier,
		searchKanji
	} from '$lib/utils/stores';
	import { draw } from 'svelte/transition';
	import { quintOut } from 'svelte/easing';
	import { hiragana } from '$lib/static/hiragana';
	import { katakana } from '$lib/static/katakana';
	import { kanji } from '$lib/static/kanji';

	export let rotationY: number;
	export let saved: any;

	// Set the correct viewBox for the SVG
	let viewBox: string;

	// Determine which object (hiragana, katakana, kanji) to use based on the URL path
	let currentObject: any;

	$: switch ($currentAlphabet) {
		case 'katakana':
			$currentLetter = $katakanaStore[Math.min($progressSlider - 1, $katakanaStore.length - 1)];
			viewBox = '0 0 1024 1024';
			currentObject = katakana;
			break;
		case 'kanji':
			viewBox = '0 0 109 109';
			// Get only the kanji that match the selected grade if selectedKanjiGrade is not 0
			// kanji is an object of objects, so we need to use Object.values() to get an array of objects
			// Then we filter the array of objects based on the grade
			// Finally, return  the array of objects back to an object of objects

			if ($selectedKanjiGrade === 'saved') {
				const savedKanji = {};

				// Find all kanji that are saved in the saved array by its name
				for (const kanjiChar in kanji) {
					if (saved.find((k) => k.name === kanjiChar)) savedKanji[kanjiChar] = kanji[kanjiChar];
				}

				$kanjiLength = Object.values(savedKanji).length;
				$kanjiWidthMulitplier = 100 / $kanjiLength;

				// Check if progressSlider is within valid range
				const sliderIndex = Math.min($progressSlider - 1, $kanjiLength - 1);
				const kanjiKeys = Object.keys(savedKanji);

				// Set the current letter based on sliderIndex
				$currentLetter = kanjiKeys[sliderIndex];

				currentObject = savedKanji;

				// Set the current letter to the first kanji if the searchKanji is not empty
				if ($searchKanji && kanjiKeys.find((k) => $searchKanji === k))
					$currentLetter = $searchKanji;
			} else if (+$selectedKanjiGrade !== 0) {
				// Filter the kanji objects based on the selected grade
				const filteredKanji = {};

				for (const kanjiChar in kanji) {
					if (kanji[kanjiChar].grade === +$selectedKanjiGrade)
						filteredKanji[kanjiChar] = kanji[kanjiChar];
				}

				$kanjiLength = Object.values(filteredKanji).length;
				$kanjiWidthMulitplier = 100 / $kanjiLength;

				// Check if progressSlider is within valid range
				const sliderIndex = Math.min($progressSlider - 1, $kanjiLength - 1);
				const kanjiKeys = Object.keys(filteredKanji);

				// Set the current letter based on sliderIndex
				$currentLetter = kanjiKeys[sliderIndex];

				currentObject = filteredKanji;

				$progressSlider = Math.min($progressSlider, $kanjiLength);

				// Set the current letter to the first kanji if the searchKanji is not empty
				if ($searchKanji && kanjiKeys.find((k) => $searchKanji === k))
					$currentLetter = $searchKanji;
			} else {
				currentObject = kanji;
				$currentLetter = $kanjiStore[Math.min($progressSlider - 1, $kanjiStore.length - 1)];

				// Get the length of the kanji
				$kanjiLength = $kanjiStore.length;

				// Get the width multiplier for the progress slider
				$kanjiWidthMulitplier = 100 / $kanjiLength;

				// Set the current letter to the first kanji if the searchKanji is not empty
				if ($searchKanji && $kanjiStore.find((k) => $searchKanji === k))
					$currentLetter = $searchKanji;
			}

			break;
		default:
			$currentLetter = $hiraganaStore[Math.min($progressSlider - 1, $hiraganaStore.length - 1)];
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
