<script lang="ts">
	import type { Ctx } from '$lib/utils/ambient.d.ts';
	import { currentAlphabet, currentFlashcard, currentIndexStore } from '$lib/utils/stores';
	import { onMount } from 'svelte';
	import { cubicOut } from 'svelte/easing';
	import { tweened } from 'svelte/motion';
	import Letter from '$lib/components/canvas/Letter.svelte';
	import Canvas from '$lib/components/canvas/Canvas.svelte';
	import MobileNav from '$lib/components/MobileNav.svelte';
	import { page } from '$app/stores';

	import { isKanji } from 'wanakana';

	const rotateYCard = tweened(0, {
		duration: 2000,
		easing: cubicOut
	});
	// Get the alphabet store length
	let canvas: HTMLCanvasElement;
	let ctx: Ctx;

	// Get canvas and context
	onMount(() => {
		canvas = document.querySelector('canvas') as HTMLCanvasElement;
		ctx = canvas.getContext('2d') as Ctx;

		// Get the last segment of the URL path (assuming it contains the identifier you need)
		$currentAlphabet = isKanji($currentFlashcard) ? 'kanji' : 'word';

		$currentIndexStore = +($page.url.pathname?.split('-').at(-1) ?? 0);
	});
</script>

<section class="mb-24 flex flex-1 flex-col justify-center gap-2 sm:justify-center sm:gap-5">
	<div class="relative">
		<Canvas rotationY={$rotateYCard} {canvas} {ctx} />
		<Letter rotationY={$rotateYCard} />

		<span
			class="{$rotateYCard > 5
				? 'hidden'
				: 'text-black'} absolute right-3 top-3 z-30 text-lg font-medium sm:right-5 sm:top-5"
		>
			{$currentFlashcard}
		</span>
	</div>

	<!-- {#if $currentAlphabet === 'kanji'}
		<Canvas rotationY={$rotateYCard} {canvas} {ctx} />
		<Letter rotationY={$rotateYCard} />

		<span
			class="{$rotateYCard > 5
				? 'hidden'
				: 'text-black'} absolute right-3 top-3 z-30 text-lg font-medium sm:right-5 sm:top-5"
		>
			{$currentFlashcard}
		</span>
	{/if} -->

	<MobileNav />
</section>
