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
	import { cn } from '$lib/utils';

	let longPressTimer: any;
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
		class={cn(
			'mx-auto flex h-14 w-20 select-none items-center justify-center rounded-full bg-black p-2 text-white transition-all sm:gap-20 lg:bottom-5',
			!$isLongPress && 'w-full justify-between px-10 py-4'
		)}
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
			<Brush class="size-5 sm:size-6" />
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
				<Eraser class="size-5 sm:size-6" />
			</button>
			<button
				on:click|preventDefault={() => {
					$animateSVG = !$animateSVG;
					// setTimeout(() => ($animateSVG = true), 250);
				}}
				class="transition-transform active:rotate-180"
			>
				<RefreshCcw class="size-5 sm:size-6" />
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
					<MoveHorizontal class="size-5 sm:size-6" />
				</button>
			{/if}
		{/if}
	</nav>
{/if}
