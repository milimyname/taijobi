<script lang="ts">
	import {
		hiraganaStore,
		showProgressSlider,
		progressSlider,
		currentAlphabet,
		kanjiLength,
		searchKanji,
		selectedKanjiGrade,
		katakanaStore,
	} from '$lib/utils/stores';
	import { clickOutside } from '$lib/utils/clickOutside';
	import { spring } from 'svelte/motion';
	import { getRandomNumber } from '$lib/utils/actions';
	import { afterNavigate } from '$app/navigation';
	import { Slider } from '$lib/components/ui/slider/index';
	import { onMount } from 'svelte';

	let progress = spring(1, { stiffness: 0.1, damping: 0.5 });
	let max: number;
	let value: number;

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

	afterNavigate(() => {
		$showProgressSlider = false;

		$progress = getRandomNumber(1, getAlphabetLength());

		max = getAlphabetLength();

		$progressSlider = $progress > max ? getRandomNumber(1, getAlphabetLength()) : $progress;

		$selectedKanjiGrade = '0';
	});

	onMount(() => {
		// find div  by id svelte-announcer and remove
		const announcer = document.getElementById('svelte-announcer');
		if (announcer) announcer.remove();
	});

	$: value = $progressSlider;

	$: max = $kanjiLength;
</script>

{#if $showProgressSlider}
	<div use:clickOutside={() => ($showProgressSlider = false)} class="mb-4 sm:my-0">
		<Slider
			value={[value]}
			onValueChange={(v) => {
				$progress = v[0];
				$progressSlider = v[0];

				$searchKanji = '';
			}}
			{max}
			min={1}
			step={1}
		/>
	</div>
{/if}
