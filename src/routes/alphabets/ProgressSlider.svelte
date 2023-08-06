<script lang="ts">
	import { slide } from 'svelte/transition';
	import { sineIn } from 'svelte/easing';
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

		// Calculate the x position relative to the slider element
		let rect = sliderElement.getBoundingClientRect();
		let x = e.type === 'touchmove' ? e.touches[0].clientX - rect.left : e.clientX - rect.left;
		let width = rect.right - rect.left;
		let newProgress = (x / width) * 100;

		// Limit the newProgress to the length of hiraganaStore array
		const maxLength =
			$currentAlphabet === 'hiragana' ? $hiraganaStore.length : $katakanaStore.length;
		newProgress = Math.min(Math.max(newProgress, 1), maxLength);

		// Update the progress with the spring animation
		progress.set(newProgress);
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
		class="z-40 mx-auto w-full overflow-hidden rounded-full bg-slate-400 shadow-2xl"
		transition:slide={{
			delay: 0,
			duration: 250,
			axis: 'y',
			easing: sineIn
		}}
		on:mousedown={start}
		on:mouseup={end}
		on:mousemove|preventDefault={move}
		on:touchstart={start}
		on:touchend={end}
		on:touchmove|preventDefault={move}
	>
		<div
			class="bar relative rounded-full bg-[#0A6EBD] py-8 shadow-xl"
			style={`width: ${
				Math.floor($progressSlider) > 0 ? Math.floor($progressSlider) * hiraganaWidthMulitplier : 0
			}%;`}
		/>
	</button>
{/if}
