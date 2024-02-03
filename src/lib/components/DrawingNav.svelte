<script lang="ts">
	import { fly } from 'svelte/transition';
	import { sineIn } from 'svelte/easing';
	import type { Ctx } from '$lib/utils/ambient.d.ts';
	import { animateSVG, isLongPress, strokeColor, showProgressSlider } from '$lib/utils/stores';
	import {
		handleUserIconClick,
		handleLongPress,
		handleCancelPress,
		clearCanvas
	} from '$lib/utils/actions';
	import { onMount } from 'svelte';
	import { Brush, Eraser, RefreshCcw, MoveHorizontal } from 'lucide-svelte';
	import { page } from '$app/stores';

	let longPressTimer: NodeJS.Timeout;
	let canvas: HTMLCanvasElement, ctx: Ctx;

	// Get canvas and context
	onMount(() => {
		canvas = document.querySelector('canvas') as HTMLCanvasElement;
		ctx = canvas.getContext('2d') as Ctx;
	});

	// When the progress changes, clear the canvas
	$: if ($showProgressSlider) clearCanvas(ctx, canvas);
</script>

{#if !$showProgressSlider}
	<nav
		class=" {!$isLongPress
			? 'px-10 py-4'
			: 'ml-auto p-2'} z-40 mb-4 mt-auto flex w-full select-none items-center justify-between rounded-full bg-black text-white transition-all sm:my-0 sm:justify-center sm:gap-20 lg:bottom-5"
	>
		<button
			on:click|preventDefault={handleUserIconClick}
			on:mousedown={() => (longPressTimer = handleLongPress())}
			on:mouseup={() => handleCancelPress(longPressTimer)}
			on:touchstart={() => (longPressTimer = handleLongPress())}
			on:touchend={() => handleCancelPress(longPressTimer)}
			class="relative select-none transition-transform hover:scale-110"
		>
			{#if !$isLongPress}
				<input type="color" class="absolute left-0 top-0 opacity-0" bind:value={$strokeColor} />
			{/if}
			<Brush class="h-5 w-5 sm:h-6 sm:w-6" />
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
				on:click|preventDefault={() => clearCanvas(ctx, canvas)}
			>
				<Eraser class="h-5 w-5 sm:h-6 sm:w-6" />
			</button>
			<button
				on:click|preventDefault={() => {
					$animateSVG = !$animateSVG;
					// setTimeout(() => ($animateSVG = true), 250);
				}}
				class="transition-transform active:rotate-180"
			>
				<RefreshCcw class="h-5 w-5 sm:h-6 sm:w-6" />
			</button>
			{#if !$page.url.pathname.includes('draw')}
				<button
					transition:fly={{
						delay: 0,
						duration: 0,
						opacity: 0,
						x: 100,
						easing: sineIn
					}}
					on:click|preventDefault={() => ($showProgressSlider = !$showProgressSlider)}
					class="select-none"
				>
					<MoveHorizontal class="h-5 w-5 sm:h-6 sm:w-6" />
				</button>
			{/if}
		{/if}
	</nav>
{/if}
