<script lang="ts">
	import * as Card from '$lib/components/ui/card/index.js';
	import * as Carousel from '$lib/components/ui/carousel/index.js';
	import { CircleX } from 'lucide-svelte';
	import { type CarouselAPI } from '$lib/components/ui/carousel/context';
	import { page } from '$app/stores';
	import { Hand, PenTool, ArrowLeft } from 'lucide-svelte';
	import { fabric } from 'fabric';
	import { IS_DESKTOP } from '$lib/utils/constants';
	import {
		innerWidthStore,
		strokeColor,
		innerHeightStore,
		currentFlashcard,
		canIdrawMultipleTimes
	} from '$lib/utils/stores';
	import { onDestroy, onMount } from 'svelte';
	import { cn, getFlashcardHeight, getFlashcardWidth } from '$lib/utils';

	export let currentIndex: number;

	let rotationY: number = 0;
	let canvasId = `${$page.params.slug}-${currentIndex}-${0}`;
	let isDrawingMode = true;

	// Skeleton sizes for the flashcard
	let width = 350;
	let height = 400;

	let canvasCarouselApi: CarouselAPI;
	let imageCarouselApi: CarouselAPI;

	const numOfItems = 5; // Number of carousel items
	let savedDrawings: string[] = [];
	let fabricCanvas: fabric.Canvas;
	let fabricCanvasMap = new Map();

	// Function to load saved drawings from localStorage
	function loadDrawing(id: string) {
		const dataUrl = localStorage.getItem(id);
		if (dataUrl) {
			fabric.Image.fromURL(dataUrl, (img) => {
				// Remove the previous image from the canvas
				fabricCanvas.clear();
				fabricCanvas.add(img);
				fabricCanvas.renderAll();
			});
		}
	}

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

	function saveDrawing() {
		localStorage.setItem(canvasId, fabricCanvas.toDataURL());
	}

	const initializeFabricCanvas = () => {
		for (let i = 0; i < numOfItems; i++) {
			fabricCanvas = new fabric.Canvas(`${$page.params.slug}-${currentIndex}-${i}`, {
				isDrawingMode
			});

			fabricCanvas.freeDrawingBrush.width = $innerWidthStore > IS_DESKTOP ? 12 : 10;
			fabricCanvas.freeDrawingBrush.color = $strokeColor;
			fabricCanvas.isDrawingMode = isDrawingMode;

			fabric.Object.prototype.transparentCorners = false;

			if (!fabricCanvas || !fabricCanvas.width || !fabricCanvas.height) return;

			// Add flashcard name to the canvas
			const text = new fabric.Text($currentFlashcard, {
				left: fabricCanvas.width / 2,
				top: fabricCanvas.height / 2,
				fontSize: 40,
				fill: 'black',
				opacity: 0.2,
				selectable: true,
				hasBorders: true,
				originX: 'center',
				originY: 'center'
			});

			fabricCanvas.add(text);
			fabricCanvas.renderAll();

			// Set up event handlers for drawing and constraining movement
			fabricCanvas.on('object:moving', (e) => {
				const obj = e.target as fabric.Object;
				obj.setCoords(); // Update the coordinates of the object

				// Check if the object has top and left properties
				if (!obj.top || !obj.left) return;

				// Constrain the object within the canvas boundaries
				if (
					obj.getBoundingRect().left < 0 ||
					obj.getBoundingRect().top < 0 ||
					obj.getBoundingRect().top + obj.getBoundingRect().height > fabricCanvas.getHeight() ||
					obj.getBoundingRect().left + obj.getBoundingRect().width > fabricCanvas.getWidth()
				) {
					obj.top = Math.min(
						obj.top,
						fabricCanvas.getHeight() - (obj.getBoundingRect().height ?? 0)
					);
					obj.left = Math.min(obj.left, fabricCanvas.getWidth() - obj.getBoundingRect().width);
					obj.top = Math.max(obj.top, 0);
					obj.left = Math.max(obj.left, 0);
				}
			});

			window.addEventListener('resize', handleResize);
			fabricCanvas.on('object:added', saveDrawing);
			fabricCanvasMap.set(`${$page.params.slug}-${currentIndex}-${i}`, fabricCanvas);
		}
	};

	function handleResize() {
		fabricCanvas.setWidth(width);
		fabricCanvas.setHeight(height);
		fabricCanvas.renderAll();
	}

	// Get canvas and context
	onMount(() => {
		fabricCanvas = fabricCanvasMap.get(canvasId);
		loadDrawing(canvasId);
		updateSavedDrawings();
		initializeFabricCanvas();
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
			const current = canvasCarouselApi.selectedScrollSnap();
			canvasId = `${$page.params.slug}-${currentIndex}-${current}`;
			// update canvas and context
			fabricCanvas = fabricCanvasMap.get(canvasId);

			loadDrawing(canvasId);
			updateSavedDrawings();
		});
	}

	$: if (imageCarouselApi && canvasCarouselApi) {
		imageCarouselApi.on('select', () => {
			canvasCarouselApi.scrollTo(imageCarouselApi.selectedScrollSnap());
		});

		addThumbBtnsClickHandlers();
	}

	function clearFabricCanvas() {
		fabricCanvas.clear();
		saveDrawing();
	}

	onDestroy(() => {
		window.removeEventListener('resize', handleResize);
	});

	$: if ($innerWidthStore || $innerHeightStore) {
		width = getFlashcardWidth($innerWidthStore);
		height = getFlashcardHeight($innerWidthStore, $innerHeightStore);
	}

	$: if (fabricCanvas) {
		fabricCanvas.freeDrawingBrush.width = $innerWidthStore > IS_DESKTOP ? 12 : 10;
		fabricCanvas.freeDrawingBrush.color = $strokeColor;
		fabricCanvas.isDrawingMode = isDrawingMode;
	}
</script>

<!-- Toggle Drawing Mode -->
<div class="flex items-center justify-center gap-2">
	<button
		on:click={() => {
			$canIdrawMultipleTimes = false;
		}}
		class="block rounded-full border bg-white p-2 shadow-sm transition-all"
	>
		<ArrowLeft class="size-5" />
	</button>

	<button
		on:click={() => {
			isDrawingMode = !isDrawingMode;
		}}
		class="block rounded-full border bg-white p-2 shadow-sm transition-all"
	>
		{#if isDrawingMode}
			<PenTool class="size-5" />
		{:else}
			<Hand class="size-5" />
		{/if}
	</button>

	<button
		on:click|preventDefault={clearFabricCanvas}
		class="block rounded-full border bg-white p-2 shadow-sm transition-all"
	>
		<CircleX class="size-5" />
	</button>
</div>

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
					<canvas
						id={`${$page.params.slug}-${currentIndex}-${i}`}
						{width}
						{height}
						class={cn(
							'relative z-10 mx-auto block cursor-pointer rounded-xl border shadow-sm bg-dotted-spacing-8 bg-dotted-gray-200',
							rotationY > 90 && 'hidden'
						)}
					/>
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
				<Card.Root class="size-20">
					<Card.Content class="flex items-center justify-center p-6">
						<img {src} alt="Saved Drawing {i}" class="size-full object-cover" />
					</Card.Content>
				</Card.Root>
			</Carousel.Item>
		{/each}
	</Carousel.Content>
</Carousel.Root>
