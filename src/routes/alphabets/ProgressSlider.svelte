<script lang="ts">
	import {
		hiraganaStore,
		showProgressSlider,
		progressSlider,
		currentAlphabet,
		kanjiLength,
		searchKanji,
		selectedKanjiGrade,
		katakanaStore
	} from '$lib/utils/stores';
	import { clickOutside } from '$lib/utils/clickOutside';
	import { spring } from 'svelte/motion';
	import { getRandomNumber } from '$lib/utils/actions';
	import { onMount } from 'svelte';
	import { createSlider, melt } from '@melt-ui/svelte';
	import { afterNavigate } from '$app/navigation';

	let progress = spring(1, { stiffness: 0.1, damping: 0.5 });

	function getAlphabetLength() {
		switch ($currentAlphabet) {
			case 'katakana':
				return $katakanaStore.length;
			case 'kanji':
				return $kanjiLength;
			default:
				return $hiraganaStore.length;
		}
	}

	const {
		elements: { root, range, thumb },
		states: { value },
		options: { max }
	} = createSlider({
		min: 1,
		max: getAlphabetLength(),
		step: 1,
		onValueChange: (value) => {
			$progress = value.curr[0];
			$progressSlider = value.curr[0];

			$searchKanji = '';
			return value.next;
		}
	});

	onMount(() => {
		$progress = getRandomNumber(1, getAlphabetLength());

		$value = [$progress];
	});

	afterNavigate(() => {
		$showProgressSlider = false;

		$progress = getRandomNumber(1, getAlphabetLength());

		$max = getAlphabetLength();

		$progressSlider = $progress;

		$selectedKanjiGrade = '0';
	});

	$: $value[0] = $progressSlider;

	$: $max = $currentAlphabet === 'kanji' ? $kanjiLength : $hiraganaStore.length;
</script>

{#if $showProgressSlider}
	<div
		use:clickOutside={() => ($showProgressSlider = false)}
		use:melt={$root}
		class="fixed bottom-2 z-40 mx-auto flex w-[90%] items-center rounded-full bg-black/40 sm:bottom-5 sm:w-[416px]"
	>
		<div class=" block h-[52px] cursor-ew-resize sm:h-[56px]">
			<div use:melt={$range} class="h-[52px] rounded-l-full bg-[#0A6EBD] shadow-xl sm:h-[56px]" />
		</div>
		<div
			use:melt={$thumb()}
			class="block h-[52px] w-2 rounded-full bg-white focus:ring-4 focus:ring-black/40 sm:h-[56px]"
		/>
	</div>
{/if}
