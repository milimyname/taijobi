<script lang="ts">
	import { browser } from '$app/environment';
	import { onDestroy, onMount } from 'svelte';
	import { spring } from 'svelte/motion';
	import type { Writable } from 'svelte/store';

	export let value: number;
	export let index: number;
	export let totalCount: number;
	export let clickedCard: Writable<boolean>;
	let showCollections = false;

	// Calculate the spring values for x, y, rotation, and scale based on index
	const x = spring(0, { stiffness: 0.1, damping: 0.8, precision: 0.1 });
	const skewX = spring(0, { stiffness: 0.1, damping: 0.5 });
	const rotateY = spring(0, { stiffness: 0.1, damping: 0.5 });
	const rotate = spring(0, { stiffness: 0.1, damping: 0.5 });
	const scale = spring(1, { stiffness: 0.1, damping: 0.8 });
	const scaleShadow = spring(0.8, { stiffness: 0.1, damping: 0.5 });

	let cardRight = 0;
	let cardLeft = 0;

	let isDragging = false;
	let cardElement: HTMLButtonElement;

	function onMouseMove(event: { clientX: number; clientY: number }) {
		if (index !== totalCount - 1) return;

		// Don't move if the mouse is in the card area, return to the intial position
		if (event.clientX > cardLeft && event.clientX < cardRight) {
			$rotateY = 0;
			$x = 0;
			$scale = 1;
			// $scaleShadow = 0.8;

			return;
		}

		if (event.clientX < cardLeft) {
			$x = -150;
			$rotateY = -35;
			$scale = 1.05;
			$skewX = 12;
			$scaleShadow = 1.2;
		}

		if (event.clientX > cardRight) {
			$x = 150;
			$rotateY = 35;
			$scale = 1.05;
			$skewX = -12;
			$scaleShadow = 1.2;
		}
	}

	function onTouchStart(event: TouchEvent) {
		event.preventDefault();

		if (!isDragging && index !== totalCount - 1) return;

		isDragging = true;
	}

	function onTouchMove(event: TouchEvent) {
		event.preventDefault();
		$x = 0;
		$rotateY = 0;
		$scale = 1 - (totalCount - index - 1) * 0.05;
		if (!isDragging && index !== totalCount - 1) return;

		const touch = event.touches[0];

		// Don't move if the mouse is in the card area, return to the intial position
		if (touch.clientX > cardLeft && touch.clientX < cardRight) {
			$rotateY = 0;
			$x = 0;
			$scale = 1;
			// $scaleShadow = 0.8;

			return;
		}

		if (touch.clientX < cardLeft) {
			$x = -150;
			$rotateY = -35;
			$rotate = -35;
			$scale = 1.05;
			$skewX = 12;

			$scaleShadow = 1.2;
		}

		if (touch.clientX > cardRight) {
			$x = 150;
			$rotateY = 35;
			$rotate = 35;
			$scale = 1.05;

			$skewX = -12;
			$scaleShadow = 1.2;
		}
	}

	function onTouchEnd(event: TouchEvent) {
		event.preventDefault();

		isDragging = false;

		if (!isDragging && index !== totalCount - 1) return;

		if ($rotateY > 10) {
			$rotateY = 60;
			$x = 1000;
			showCollections = true;
		}

		if ($rotateY < -10) {
			$rotateY = -60;
			$x = -1000;
			$clickedCard = true;
		}
	}

	function onClick(event: MouseEvent) {
		if (!isDragging && index !== totalCount - 1) return;

		if ($rotateY > 15) {
			$rotateY = 60;
			$x = 1000;
			showCollections = true;
		} else if ($rotateY < -25) {
			$rotateY = -60;
			$x = -1000;
			$clickedCard = true;
		} else if (event.clientX > cardRight && event.clientX < cardLeft) {
			showCollections = true;
		}
	}

	onMount(() => {
		window.addEventListener('touchmove', onTouchMove, { passive: false });
		window.addEventListener('touchstart', onTouchStart, { passive: false });
		window.addEventListener('touchend', onTouchEnd, { passive: false });
	});

	onDestroy(() => {
		if (!browser) return;
		window.removeEventListener('touchmove', onTouchMove);
		window.removeEventListener('touchstart', onTouchStart);
		window.removeEventListener('touchend', onTouchEnd);
	});

	$: if (browser && cardElement) {
		cardRight = cardElement.getBoundingClientRect().right;
		cardLeft = cardElement.getBoundingClientRect().left;
		if (index !== totalCount - 1) {
			$rotate = 3 + 5 * index;
			$scale = 1;
			$x = 0;
		}

		// Set z index to all cards
		// cardElement.style.zIndex = `-${index}`;
	}
</script>

<svelte:window on:mousemove={onMouseMove} on:click={onClick} />

<button
	bind:this={cardElement}
	on:click={onClick}
	style="transform: translateX({$x}px) 
		 rotateY({$rotateY}deg) rotate({$rotate}deg)
			translateZ({(totalCount - index) * 60}px) scale({$scale}); 
			z-index: {index};
			"
	class="card absolute flex h-[50dvh] w-64 select-none flex-col items-center justify-between rounded-2xl bg-white p-2 shadow-md before:absolute before:bottom-1 before:left-1 before:right-1 before:top-1 before:z-[-1] before:rounded-2xl before:bg-slate-200 sm:h-[55dvh] sm:w-80"
>
	{#if index === totalCount - 1}
		<div
			style="transform: translateZ(-20rem) translateX(10px) skewX({$skewX}deg) scale({$scaleShadow})"
			class="absolute z-[-1] h-full w-full rounded-xl bg-black/5 blur-xl"
		/>
	{/if}

	<h2>{value}</h2>
	<div class="h-40 w-full rounded-xl bg-blue-400 p-4">Hello Wold</div>
</button>

<style>
	.card {
		backface-visibility: hidden;
		transform-style: preserve-3d;
		/* box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1); Subtle shadow for depth */
	}
</style>
