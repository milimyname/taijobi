<script lang="ts">
	import { fly } from 'svelte/transition';
	import { sineIn } from 'svelte/easing';
	import {
		animateSVG,
		isLongPress,
		strokeColor,
		showProgressSlider,
		strokes,
	} from '$lib/utils/stores';
	import {
		handleUserIconClick,
		handleLongPress,
		handleCancelPress,
		clearCanvas,
		redrawCanvas,
	} from '$lib/utils/actions';
	import { onMount } from 'svelte';
	import { Brush, Eraser, RefreshCcw, MoveHorizontal, Undo2 } from 'lucide-svelte';
	import { page } from '$app/stores';
	import { cn } from '$lib/utils';

	export let className = '';

	let longPressTimer: any;
	let canvas: HTMLCanvasElement;

	function undoLastStroke() {
		if ($strokes.length > 0) {
			$strokes.pop();
			redrawCanvas(canvas);
		}
	}

	// Get canvas and context
	onMount(() => {
		canvas = document.querySelector('canvas') as HTMLCanvasElement;
	});

	function getContrastColor(hexColor: string): string {
		// Convert hex to RGB
		const r = parseInt(hexColor.slice(1, 3), 16);
		const g = parseInt(hexColor.slice(3, 5), 16);
		const b = parseInt(hexColor.slice(5, 7), 16);

		// Calculate luminance
		const luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255;

		// If the color is dark (close to black), return a light color
		return luminance < 0.15 ? '#FFFFFF' : hexColor;
	}

	$: brushColor = getContrastColor($strokeColor);

	// When the progress changes, clear the canvas
	$: if ($showProgressSlider) clearCanvas(canvas);
</script>

{#if !$showProgressSlider}
	<nav
		class={cn(
			'mx-auto flex h-14 w-20 select-none items-center justify-center rounded-full bg-black p-2 text-white transition-all sm:gap-20 lg:bottom-5',
			!$isLongPress && 'w-full justify-between px-10 py-4',
			className,
		)}
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
			<Brush class="size-5 sm:size-6" style="color: {brushColor};" />
		</button>

		{#if !$isLongPress}
			<button on:click|preventDefault={() => undoLastStroke()}>
				<Undo2 class="size-5" />
			</button>
			<button
				transition:fly={{
					delay: 0,
					duration: 0,
					opacity: 0,
					x: 100,
					easing: sineIn,
				}}
				on:click|preventDefault={() => clearCanvas(canvas)}
			>
				<Eraser class="size-5" />
			</button>
			<button
				on:click|preventDefault={() => {
					$animateSVG = !$animateSVG;
					// setTimeout(() => ($animateSVG = true), 250);
				}}
				class="transition-transform active:rotate-180"
			>
				<RefreshCcw class="size-5" />
			</button>
			{#if !$page.url.pathname.includes('draw')}
				<button
					transition:fly={{
						delay: 0,
						duration: 0,
						opacity: 0,
						x: 100,
						easing: sineIn,
					}}
					on:click|preventDefault={() => ($showProgressSlider = !$showProgressSlider)}
					class="select-none"
				>
					<MoveHorizontal class="size-5" />
				</button>
			{/if}
		{/if}
	</nav>
{/if}
