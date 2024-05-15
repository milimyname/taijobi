<script lang="ts">
	import Canvas from '$lib/components/canvas/Canvas.svelte';
	import * as Card from '$lib/components/ui/card/index.js';
	import * as Carousel from '$lib/components/ui/carousel/index.js';
	import { clearCanvas } from '$lib/utils/actions';
	import type { Ctx } from '$lib/utils/ambient.d.ts';
	import { CircleX } from 'lucide-svelte';
	import { onMount } from 'svelte';
	import { type CarouselAPI } from '$lib/components/ui/carousel/context';
	import { page } from '$app/stores';
	import { isMinScreenLG } from '$lib/utils';

	export let currentIndex: number;

	let canvasCarouselApi: CarouselAPI;
	let imageCarouselApi: CarouselAPI;

	let canvas: HTMLCanvasElement;
	let ctx: Ctx;
	let current = 0;
	const numOfItems = 5; // Number of carousel items
	let savedDrawings: string[] = [];

	// Function to load saved drawings from localStorage
	function loadDrawing(id: string, ctx: Ctx) {
		const dataUrl = localStorage.getItem(id);
		if (dataUrl) {
			const img = new Image();
			img.src = dataUrl;
			img.onload = () => {
				ctx.drawImage(img, 0, 0);
			};
		}
	}

	// Function to create a placeholder image with a point in the center
	function createPlaceholderImage() {
		const canvas = document.createElement('canvas');
		canvas.width = 800;
		canvas.height = 600;
		const ctx = canvas.getContext('2d');

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

	// Function to handle image click
	function handleImageClick(index: number) {
		console.log('image clicked', index);
		canvasCarouselApi.scrollTo(index);
	}

	// Get canvas and context
	onMount(() => {
		canvas = document.querySelector('canvas') as HTMLCanvasElement;
		ctx = canvas.getContext('2d') as Ctx;
		loadDrawing(`${$page.params.slug}-${currentIndex}-${0}`, ctx);
		updateSavedDrawings();
	});

	const addThumbBtnsClickHandlers = () => {
		const slidesThumbs = imageCarouselApi.slideNodes();

		const scrollToIndex = slidesThumbs.map((_, index) => () => canvasCarouselApi.scrollTo(index));

		slidesThumbs.forEach((slideNode, index) => {
			slideNode.addEventListener('click', scrollToIndex[index], false);
		});

		return () => {
			slidesThumbs.forEach((slideNode, index) => {
				slideNode.removeEventListener('click', scrollToIndex[index], false);
			});
		};
	};

	$: if (canvasCarouselApi) {
		canvasCarouselApi.on('select', () => {
			current = canvasCarouselApi.selectedScrollSnap() + 1;
			// update canvas and context
			canvas = document.querySelectorAll('canvas')[current - 1] as HTMLCanvasElement;
			ctx = canvas.getContext('2d') as Ctx;

			loadDrawing(`${$page.params.slug}-${currentIndex}-${current - 1}`, ctx);
			updateSavedDrawings();
		});
	}

	$: if (imageCarouselApi && canvasCarouselApi) {
		imageCarouselApi.on('select', () => {
			canvasCarouselApi.scrollTo(imageCarouselApi.selectedScrollSnap());
		});

		imageCarouselApi.on('pointerDown', () => {
			canvasCarouselApi.scrollTo(imageCarouselApi.selectedScrollSnap());
		});

		addThumbBtnsClickHandlers();
	}
</script>

<Carousel.Root
	bind:api={canvasCarouselApi}
	opts={{
		watchDrag: false
	}}
	class="w-full"
>
	<Carousel.Content>
		{#each Array(numOfItems) as _, i (i)}
			<Carousel.Item>
				<div style="perspective: 3000px;" class="mx-auto w-fit">
					<Canvas {canvas} canvasId={`${$page.params.slug}-${currentIndex}-${i}`} />

					{#if $isMinScreenLG}
						<button
							on:click|preventDefault={() => {
								clearCanvas(ctx, canvas);
							}}
							class="fixed bottom-5 left-5 z-30 block rounded-full border bg-white p-2 shadow-sm transition-all"
						>
							<CircleX />
						</button>

						<!-- <Carousel.Previous />
						<Carousel.Next /> -->
					{/if}
				</div>
			</Carousel.Item>
		{/each}
	</Carousel.Content>
</Carousel.Root>

<Carousel.Root
	bind:api={imageCarouselApi}
	opts={{
		containScroll: 'keepSnaps',
		dragFree: true
	}}
	class="flex w-full justify-center"
>
	<Carousel.Content>
		{#each savedDrawings as src, i (i)}
			<Carousel.Item
				class="flex basis-auto cursor-pointer items-center justify-center  first:pl-0 md:pl-10"
			>
				<Card.Root
					class="size-20"
					on:click={() => {
						handleImageClick(i);
					}}
				>
					<Card.Content class="flex items-center justify-center p-6">
						<img {src} alt="Saved Drawing {i}" class="size-full object-cover" />
					</Card.Content>
				</Card.Root>
			</Carousel.Item>
		{/each}
	</Carousel.Content>
</Carousel.Root>
