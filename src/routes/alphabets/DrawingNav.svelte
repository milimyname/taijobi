<script lang="ts">
	import { twSmallScreen } from '$lib/utils/constants';
	import { fly } from 'svelte/transition';
	import { sineIn } from 'svelte/easing';
	import type { Ctx } from '$lib/utils/ambient.d.ts';

	import {
		animateSVG,
		innerWidthStore,
		isLongPress,
		strokeColor,
		showProgressSlider
	} from '$lib/utils/stores';
	import { icons } from '$lib/utils/icons';
	import {
		handleUserIconClick,
		handleLongPress,
		handleCancelPress,
		clearCanvas
	} from '$lib/utils/actions';
	import { onMount } from 'svelte';

	let longPressTimer: NodeJS.Timeout;
	let canvas: HTMLCanvasElement | null, ctx: Ctx;

	// Get canvas and context
	onMount(() => {
		canvas = document.querySelector('canvas');
		ctx = canvas.getContext('2d') as Ctx;
	});

	// When the progress changes, clear the canvas
	$: if ($showProgressSlider) clearCanvas(ctx, canvas);
</script>

{#if !$showProgressSlider}
	<nav
		class=" {!$isLongPress
			? 'w-full px-10 py-4'
			: 'ml-auto p-2'} z-40 flex items-center justify-between rounded-full bg-black text-white transition-all sm:w-auto sm:justify-center sm:gap-20 sm:px-10 sm:py-5"
	>
		<button
			on:click={handleUserIconClick}
			on:mousedown={() => (longPressTimer = handleLongPress())}
			on:mouseup={() => handleCancelPress(longPressTimer)}
			on:touchstart={() => (longPressTimer = handleLongPress())}
			on:touchend={() => handleCancelPress(longPressTimer)}
			class="relative select-none transition-transform hover:scale-110"
		>
			{#if !$isLongPress}
				<input type="color" class="absolute left-0 top-0 opacity-0" bind:value={$strokeColor} />
			{/if}
			{@html icons.draw}
		</button>

		{#if !$isLongPress}
			<button
				transition:fly={{
					delay: 0,
					duration: 0,
					opacity: 0,
					x: 100,
					easing: sineIn
				}}
				on:click={() => clearCanvas(ctx, canvas)}
			>
				{@html icons.erase}
			</button>
			<button
				on:click={() => {
					$animateSVG = false;
					setTimeout(() => ($animateSVG = true), 250);
				}}
				class="transition-transform active:rotate-180"
			>
				{@html icons.animate}
			</button>
			<button
				transition:fly={{
					delay: 0,
					duration: 0,
					opacity: 0,
					x: 100,
					easing: sineIn
				}}
				on:click={() => ($showProgressSlider = !$showProgressSlider)}
			>
				{@html icons.rotate}
			</button>
		{/if}
	</nav>
{/if}
