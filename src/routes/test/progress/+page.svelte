<script lang="ts">
	import { onMount } from 'svelte';
	import { hiraganaStore, currentAlphabet, kanjiLength, progressSlider } from '$lib/utils/stores';
	import { spring } from 'svelte/motion';
	import { createSlider, melt } from '@melt-ui/svelte';
	import { getRandomNumber } from '$lib/utils/actions';

	let progress = spring(0, { stiffness: 0.1, damping: 0.5 });

	const {
		elements: { root, range, thumb },
		states: { value }
	} = createSlider({
		min: 0,
		max: $currentAlphabet === 'kanji' ? $kanjiLength : $hiraganaStore.length,
		step: 1,
		onValueChange: (value) => {
			$progress = value.curr[0];
			return value.next;
		}
	});

	onMount(async () => {
		console.log('dsad');

		let initialValue;
		if ($currentAlphabet !== 'kanji') initialValue = getRandomNumber(1, 46);
		else initialValue = getRandomNumber(1, $kanjiLength);

		$progress = initialValue;
		$value = [$progress];
		$progress = $value[0];
	});
</script>

<h1>{Math.floor($progress)}</h1>

<span use:melt={$root} class="relative flex h-[20px] w-[200px] items-center">
	<span class="block h-[67px] w-full cursor-ew-resize overflow-hidden rounded-full bg-black/40">
		<span use:melt={$range} class="bar relative h-[67px] rounded-l-full bg-[#0A6EBD] shadow-xl" />
	</span>
	<span
		use:melt={$thumb()}
		class=" block h-[67px] w-2 rounded-full bg-white focus:ring-4 focus:ring-black/40"
	/>
</span>
