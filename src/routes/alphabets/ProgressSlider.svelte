<script lang="ts">
	import {
		hiraganaStore,
		showProgressSlider,
		progressSlider,
		innerWidthStore,
		katakanaStore,
		currentAlphabet,
		kanjiLength,
		kanjiWidthMulitplier,
		searchKanji
	} from '$lib/utils/stores';
	import { clickOutside } from '$lib/utils/clickOutside';
	import { spring } from 'svelte/motion';
	import { hiraganaWidthMulitplier, twSmallScreen } from '$lib/utils/constants';
	import { getRandomNumber } from '$lib/utils/actions';

	let mousedown = false;
	let progress = spring(getRandomNumber(1, $kanjiLength), {
		stiffness: 0.1,
		damping: 0.4
	});

	// Get the width multiplier for the progress slider
	let progressWidthMultiplier: number;

	let initialX = 0; // track the initial X position on drag start
	let initialValue = 0; // track the initial slider value on drag start

	const start = (e: any) => {
		mousedown = true;

		initialValue = $progress; // store the initial slider value

		if (e.type === 'touchstart') initialX = e.touches[0].clientX;
		else initialX = e.clientX;
	};

	const end = () => {
		mousedown = false;
	};

	const move = (e: any) => {
		if (!mousedown) return;

		let currentX;

		currentX = e.type === 'touchmove' ? e.touches[0].clientX : (currentX = e.clientX);

		const deltaX = currentX - initialX; // difference from initial position
		const sensitivity = 0.5; // adjust as needed for smoother or sharper response
		let change = Math.round(deltaX * sensitivity);

		let newProgress = initialValue + change;

		// Get the alphabet store length
		let maxLength;
		switch ($currentAlphabet) {
			case 'katakana':
				maxLength = $katakanaStore.length;
				progressWidthMultiplier = hiraganaWidthMulitplier;
				break;
			case 'kanji':
				maxLength = $kanjiLength;
				progressWidthMultiplier = $kanjiWidthMulitplier;
				break;
			default:
				maxLength = $hiraganaStore.length;
				progressWidthMultiplier = hiraganaWidthMulitplier;
		}

		// Limit the newProgress to the length of alphabet array
		newProgress = Math.min(Math.max(newProgress, 1), maxLength);

		// Update the progress with the spring animation
		$progress = Math.floor(newProgress);

		$searchKanji = '';
	};

	$: {
		// Update the progress value
		switch ($currentAlphabet) {
			case 'hiragana':
				progressWidthMultiplier = hiraganaWidthMulitplier;
				break;
			case 'katakana':
				progressWidthMultiplier = hiraganaWidthMulitplier;
				break;
			case 'kanji':
				progressWidthMultiplier = $kanjiWidthMulitplier;
				break;
		}

		if ($progress < 1) $progress = 1;

		// Update the progress slider value
		$progressSlider = Math.floor($progress);

		// Update the progress slider visibility
		$innerWidthStore > twSmallScreen && ($showProgressSlider = false);
	}
</script>

{#if $showProgressSlider}
	<button
		use:clickOutside
		on:outsideclick={() => ($showProgressSlider = false)}
		class="z-40 mx-auto w-full cursor-ew-resize overflow-hidden rounded-full bg-slate-400 shadow-2xl"
		on:mousedown={start}
		on:mouseup={end}
		on:mousemove|preventDefault={move}
		on:touchstart={start}
		on:touchend={end}
		on:touchmove|preventDefault={move}
	>
		<div
			class="bar relative h-[67px] rounded-full bg-[#0A6EBD] shadow-xl"
			style={`width: ${
				Math.floor($progressSlider) > 0 ? Math.floor($progressSlider) * progressWidthMultiplier : 0
			}%;`}
		/>
	</button>
{/if}
