<script lang="ts">
	import { twSmallScreen } from '$lib/utils/constants';
	import { fly, slide } from 'svelte/transition';
	import { sineIn } from 'svelte/easing';
	import {
		animateSVG,
		innerWidthStore,
		isLongPress,
		strokeColor,
		showProgressSlider,
		currentAlphabet,
		currentLetter
	} from '$lib/utils/stores';
	import { icons } from '$lib/utils/icons';
	import {
		handleUserIconClick,
		handleLongPress,
		handleCancelPress,
		clearCanvas
	} from '$lib/utils/actions';
	import { onMount } from 'svelte';
	import { hiragana } from '$lib/static/hiragana';
	import { katakana } from '$lib/static/katakana';

	let longPressTimer: NodeJS.Timeout;
	let canvas: HTMLCanvasElement | null,
		ctx: {
			strokeStyle: string;
			beginPath: () => void;
			moveTo: (arg0: number, arg1: number) => void;
			lineTo: (arg0: number, arg1: number) => void;
			stroke: () => void;
			lineWidth: number;
		};

	// Get canvas and context
	onMount(() => {
		canvas = document.querySelector('canvas');
		ctx = canvas.getContext('2d');
	});

	// When the progress changes, clear the canvas
	$: if ($showProgressSlider) clearCanvas(ctx, canvas);
</script>

{#if !$showProgressSlider}
	<nav
		transition:slide={{
			delay: 0,
			duration: 250,
			axis: 'y',
			easing: sineIn
		}}
		class=" {!$isLongPress
			? 'w-full px-10 py-4'
			: 'ml-auto p-2'} z-40 flex items-center justify-between rounded-full bg-black text-white transition-all sm:h-full sm:w-auto sm:flex-col sm:justify-center sm:gap-10 sm:p-5"
	>
		{#if $innerWidthStore > twSmallScreen}
			<a href="/" class="mb-auto">
				<img src="/taijobi.png" class="h-10 w-10 sm:h-12 sm:w-12" alt="Logo" />
			</a>
			<div class="flex gap-10 sm:flex-col">
				<a href="/signup">{@html icons.signup} </a>
				<a href="/studying">{@html icons.saved} </a>
				<a href="/news">{@html icons.news} </a>
				<form action="/logout" method="POST">
					<button type="submit">
						{@html icons.logout}
					</button>
				</form>
			</div>
			<a href="/" class="mt-auto">
				<img src="/taijobi.png" alt="Logo" />
			</a>
		{:else}
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
						setTimeout(
							() => ($animateSVG = true),
							$currentAlphabet === 'hiragana'
								? hiragana[$currentLetter].ds.length * 1000
								: katakana[$currentLetter].ds.length * 1000
						);
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
		{/if}
	</nav>
{/if}
