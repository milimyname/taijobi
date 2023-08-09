<script lang="ts">
	import {
		hiraganaStore,
		showProgressSlider,
		progressSlider,
		innerWidthStore,
		katakanaStore,
		currentAlphabet
	} from '$lib/utils/stores';
	import { clickOutside } from '$lib/utils/clickOutside';
	import { spring } from 'svelte/motion';
	import { hiraganaWidthMulitplier, twSmallScreen } from '$lib/utils/constants';
	import { getRandomNumber } from '$lib/utils/actions';

	let mousedown = false;
	let progress = spring(getRandomNumber(1, 46));

	const start = () => {
		mousedown = true;
	};

	const end = () => {
		mousedown = false;
	};

	const move = (e: any) => {
		if (!mousedown && e.type !== 'touchmove') return;

		// Get the slider element reference
		const sliderElement = e.target;

		// Get the alphabet store length
		const maxLength =
			$currentAlphabet === 'hiragana' ? $hiraganaStore.length : $katakanaStore.length;

		// Calculate the x position relative to the slider element
		let newProgress =
			e.type === 'touchmove'
				? (e.touches[0].clientX / sliderElement.offsetWidth) * maxLength
				: (e.clientX / sliderElement.offsetWidth) * maxLength;

		// Limit the newProgress to the length of alphabet array
		newProgress = Math.min(Math.max(newProgress, 1), maxLength);

		// Update the progress with the spring animation
		$progress = Math.floor(newProgress);
		$progressSlider = Math.floor(newProgress);
	};

	$: {
		// Update the progress value
		if ($currentAlphabet === 'hiragana' && $progress > $hiraganaStore.length)
			$progress = $hiraganaStore.length;
		if ($currentAlphabet === 'katakana' && $progress > $katakanaStore.length)
			$progress = $katakanaStore.length;
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
				Math.floor($progressSlider) > 0 ? Math.floor($progressSlider) * hiraganaWidthMulitplier : 0
			}%;`}
		/>
	</button>
{/if}
