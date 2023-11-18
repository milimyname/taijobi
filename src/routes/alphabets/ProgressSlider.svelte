<script lang="ts">
	import {
		hiraganaStore,
		showProgressSlider,
		progressSlider,
		currentAlphabet,
		kanjiLength,
		searchKanji,
		selectedKanjiGrade
	} from '$lib/utils/stores';
	import { clickOutside } from '$lib/utils/clickOutside';
	import { spring } from 'svelte/motion';
	import { getRandomNumber } from '$lib/utils/actions';
	import { onMount } from 'svelte';
	import { createSlider, melt } from '@melt-ui/svelte';
	import { afterNavigate } from '$app/navigation';

	let progress = spring(1, { stiffness: 0.1, damping: 0.5 });

	const {
		elements: { root, range, thumb },
		states: { value },
		options: { max }
	} = createSlider({
		min: 1,
		max: $currentAlphabet === 'kanji' ? $kanjiLength : $hiraganaStore.length,
		step: 1,
		onValueChange: (value) => {
			$progress = value.curr[0];
			$progressSlider = value.curr[0];

			$searchKanji = '';
			return value.next;
		}
	});

	onMount(() => {
		$progress =
			$currentAlphabet !== 'kanji' ? getRandomNumber(1, 46) : getRandomNumber(1, $kanjiLength);
		$value = [$progress];
	});

	afterNavigate(() => {
		$showProgressSlider = false;
		$progress =
			$currentAlphabet !== 'kanji' ? getRandomNumber(1, 46) : getRandomNumber(1, $kanjiLength);

		$max = $currentAlphabet === 'kanji' ? $kanjiLength : $hiraganaStore.length;

		$progressSlider = $progress;

		console.log('updated', { $progress, $progressSlider, $value: $value[0], $kanjiLength });

		$selectedKanjiGrade = '0';
	});

	$: $value[0] = $progressSlider;
</script>

{#if $showProgressSlider}
	<div
		use:clickOutside
		on:outsideclick={() => ($showProgressSlider = false)}
		use:melt={$root}
		class="fixed bottom-5 z-40 mx-auto flex w-[90%] items-center overflow-hidden rounded-full bg-black/40"
	>
		<div class=" block h-[67px] cursor-ew-resize">
			<div use:melt={$range} class="h-[67px] rounded-l-full bg-[#0A6EBD] shadow-xl" />
		</div>
		<div
			use:melt={$thumb()}
			class=" block h-[67px] w-2 overflow-auto rounded-full bg-white focus:ring-4 focus:ring-black/40"
		/>
	</div>
{/if}
