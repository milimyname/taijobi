<script lang="ts">
	import * as Carousel from '$lib/components/ui/carousel/index.js';
	import { type CarouselAPI } from '$lib/components/ui/carousel/context';
	import { page } from '$app/stores';

	import { onMount } from 'svelte';
	import ExcalidrawWrapper from '$lib/components/excalidraw/AsyncExcalidraw.svelte';
	import { cn } from '$lib/utils';

	export let currentIndex: number;

	let imageCarouselApi: CarouselAPI;

	const numOfItems = 5; // Number of carousel items
	let savedDrawings: string[] = [];
	let current = 0;

	let canvas: HTMLCanvasElement;
	let canvasId = '.excalidraw__canvas';

	// Function to load saved drawings from localStorage
	// function loadDrawing(id: string) {
	// 	const dataUrl = localStorage.getItem(id);
	// 	if (dataUrl) {
	// 		fabric.Image.fromURL(dataUrl, (img) => {
	// 			// Remove the previous image from the canvas
	// 			fabricCanvas.clear();
	// 			fabricCanvas.add(img);
	// 			fabricCanvas.renderAll();
	// 		});
	// 	}
	// }

	// Function to create a placeholder image with a point in the center
	function createPlaceholderImage() {
		const canvas = document.createElement('canvas');
		canvas.width = 800;
		canvas.height = 600;

		return canvas.toDataURL();
	}

	// Function to load saved drawings from localStorage
	function updateSavedDrawings() {
		savedDrawings = [];
		for (let i = 0; i < numOfItems; i++) {
			const dataUrl = localStorage.getItem(`${$page.params.slug}-${currentIndex}-${i}`);
			if (dataUrl) savedDrawings.push(dataUrl);
			else savedDrawings.push(createPlaceholderImage());
		}
	}

	// function saveDrawing() {
	// 	localStorage.setItem(canvasId, canvas.toDataURL());
	// }

	function handleClick(i?: number) {
		if (!canvas) return;

		const ctx = canvas.getContext('2d') as CanvasRenderingContext2D;

		// Save the current drawing
		localStorage.setItem(`${$page.params.slug}-${currentIndex}-${i}`, canvas.toDataURL());

		// Clear the canvas
		ctx.clearRect(0, 0, canvas.width, canvas.height);

		// Go to the next drawing
		// console.log('Scrolling to', { i, canvas });

		// imageCarouselApi.scrollTo(i);
		// imageCarouselApi.scrollNext();

		const saved_canvas = `excalidraw__canvas-${$page.params.slug}-${i}`;
	}

	// Get canvas and context
	onMount(() => {
		updateSavedDrawings();

		// Delayed check for the canvas
		setTimeout(() => {
			canvas = document.querySelector('.excalidraw__canvas') as HTMLCanvasElement;
		}, 250); //
	});

	$: if (imageCarouselApi) {
		current = imageCarouselApi.selectedScrollSnap();

		imageCarouselApi.on('select', () => {
			current = imageCarouselApi.selectedScrollSnap();

			handleClick();

			console.log('Selected', current);
		});

		canvas = document.querySelector(canvasId) as HTMLCanvasElement;

		// console.log('Clicked imageCarouselApi', canvas);
	}
</script>

<ExcalidrawWrapper />

<Carousel.Root
	bind:api={imageCarouselApi}
	opts={{
		dragFree: true
	}}
>
	<Carousel.Content>
		{#each savedDrawings as src, i (i)}
			<Carousel.Item class="basis-full cursor-pointer">
				<button
					class={cn('size-20 rounded-lg border shadow-sm', {
						'border-2 border-black': i === current
					})}
					on:click={() => handleClick(i)}
				>
					<img {src} alt="Saved Drawing {i}" class="size-full object-cover" />
				</button>
			</Carousel.Item>
		{/each}
	</Carousel.Content>
	<Carousel.Previous />
	<Carousel.Next />
</Carousel.Root>
