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
		searchKanji,
		currentFlashcard
	} from '$lib/utils/stores';
	import { draw } from 'svelte/transition';
	import { quintOut } from 'svelte/easing';
	import { hiragana } from '$lib/static/hiragana';
	import { katakana } from '$lib/static/katakana';
	import { kanji } from '$lib/static/kanji';
	import { page } from '$app/stores';

	type SavedLetter = {
		[x: string]: any;
		name?: string;
	};

	export let rotationY: number;
	export let saved: SavedLetter = {
		name: ''
	};

	// Determine which object (hiragana, katakana, kanji) to use based on the URL path
	let currentObject: any;

	// Set the current letter and object based on the currentAlphabet
	function setCurrentLetterAndObject(store: string[], object: any) {
		$currentLetter = store[Math.min($progressSlider - 1, store.length - 1)];
		currentObject = object;
	}

	$: switch ($currentAlphabet) {
		case 'katakana':
			setCurrentLetterAndObject($katakanaStore, katakana);
			break;
		case 'kanji':
			if ($currentFlashcard !== '' && $page.url.pathname.includes('flashcards')) {
				currentObject = kanji;
				// Find the kanji that matches the saved name
				for (const kanjiChar in kanji) {
					if (kanjiChar === $currentFlashcard) $currentLetter = kanjiChar;
				}
			} else if ($selectedKanjiGrade === 'saved') {
				const savedKanji: SavedLetter = {
					name: ''
				};
				// Find all kanji that are saved in the saved array by its name
				for (const kanjiChar in kanji) {
					if (saved.find((k: { name: string }) => k.name === kanjiChar))
						savedKanji[kanjiChar] = kanji[kanjiChar];
				}

				$kanjiLength = Object.values(savedKanji).length;
				$kanjiWidthMulitplier = 100 / $kanjiLength;

				// Check if progressSlider is within valid range
				const sliderIndex = Math.min($progressSlider, $kanjiLength - 1);
				const kanjiKeys = Object.keys(savedKanji);

				// Set the current letter based on sliderIndex
				$currentLetter = kanjiKeys[sliderIndex];

				currentObject = savedKanji;

				// Set the current letter to the first kanji if the searchKanji is not empty
				if ($searchKanji && kanjiKeys.find((k) => $searchKanji === k))
					$currentLetter = $searchKanji;
			} else if (+$selectedKanjiGrade !== 0) {
				// Filter the kanji objects based on the selected grade
				const filteredKanji: SavedLetter = {};

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
			setCurrentLetterAndObject($hiraganaStore, hiragana);
	}
</script>

{#if currentObject[$currentLetter]}
	<svg
		xmlns="http://www.w3.org/2000/svg"
		viewBox="0 0 110 117"
		fill="none"
		class="absolute {$currentAlphabet === 'hiragana' || $currentAlphabet === 'katakana'
			? 'left-1/2 top-1/2'
			: 'left-1/2 top-1/2'}
		{rotationY > 5 ? 'hidden' : 'block'} sm:w-26 w-80
		-translate-x-1/2 -translate-y-1/2 overflow-hidden opacity-20 sm:left-[50%] sm:top-1/2 sm:-translate-y-1/2"
	>
		{#each currentObject[$currentLetter].ds as path, index}
			{#if $animateSVG}
				<path
					d={path}
					stroke="black"
					stroke-width="3"
					stroke-linecap="round"
					stroke-linejoin="round"
					in:draw={{ duration: 1000, delay: index * 1000, easing: quintOut }}
				/>
			{/if}
		{/each}
	</svg>
{:else}
	Not Found
{/if}
