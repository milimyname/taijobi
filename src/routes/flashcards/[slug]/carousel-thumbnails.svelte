<script lang="ts">
	import * as Card from '$lib/components/ui/card/index.js';
	import * as Carousel from '$lib/components/ui/carousel/index.js';
	import { CircleX } from 'lucide-svelte';
	import { type CarouselAPI } from '$lib/components/ui/carousel/context';
	import { page } from '$app/stores';
	import { Hand, PenTool, FileText, Undo2 } from 'lucide-svelte';
	import { fabric } from 'fabric';
	import { IS_DESKTOP, NUM_OF_THUMBAILS } from '$lib/utils/constants';
	import {
		innerWidthStore,
		strokeColor,
		innerHeightStore,
		currentFlashcard,
		canIdrawMultipleTimes,
	} from '$lib/utils/stores';
	import { onDestroy, onMount } from 'svelte';
	import { cn, getFlashcardHeight, getFlashcardWidth } from '$lib/utils';
	import * as Tooltip from '$lib/components/ui/tooltip/index.js';

	export let currentIndex: number;

	let rotationY: number = 0;
	let canvasId = `${$page.params.slug}-${currentIndex}-${0}`;
	let isDrawingMode = true;
	let current = 0;

	// Skeleton sizes for the flashcard
	let width = 350;
	let height = 400;

	let canvasCarouselApi: CarouselAPI;
	let imageCarouselApi: CarouselAPI;

	let savedDrawings: string[] = [];
	let fabricCanvas: fabric.Canvas;
	let fabricCanvasMap = new Map();

	// Function to load saved drawings from localStorage
	function loadDrawing(id: string) {
		const jsonCanvas = localStorage.getItem(id);
		if (jsonCanvas && fabricCanvas) {
			// Clear the canvas first
			fabricCanvas.clear();

			// Load the JSON string back into the canvas
			fabricCanvas.loadFromJSON(jsonCanvas, function () {
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
		for (let i = 0; i < NUM_OF_THUMBAILS; i++) {
			const json = localStorage.getItem(`${$page.params.slug}-${currentIndex}-${i}`);
			if (json) {
				// Create a new Fabric canvas and load serialized data
				const tempCanvas = document.createElement('canvas');
				// Add width and height to the canvas 80 px

				tempCanvas.width = 800;
				tempCanvas.height = 600;

				const tempFabricCanvas = new fabric.Canvas(tempCanvas);

				tempFabricCanvas.loadFromJSON(json, () => {
					// After data is loaded and canvas is ready
					const url = tempFabricCanvas.toDataURL();
					savedDrawings.push(url);
					tempFabricCanvas.dispose(); // Clean up
					tempCanvas.remove();
				});
			} else {
				savedDrawings.push(createPlaceholderImage());
			}
		}
	}

	function saveDrawing() {
		// Serialize the canvas to JSON
		const jsonCanvas = fabricCanvas.toJSON();
		localStorage.setItem(canvasId, JSON.stringify(jsonCanvas));
	}

	const initializeFabricCanvas = () => {
		for (let i = 0; i < NUM_OF_THUMBAILS; i++) {
			fabricCanvas = new fabric.Canvas(`${$page.params.slug}-${currentIndex}-${i}`, {
				isDrawingMode,
			});

			fabricCanvas.freeDrawingBrush.width = $innerWidthStore > IS_DESKTOP ? 12 : 10;
			fabricCanvas.freeDrawingBrush.color = $strokeColor;
			fabricCanvas.isDrawingMode = isDrawingMode;

			fabric.Object.prototype.transparentCorners = false;

			if (!fabricCanvas || !fabricCanvas.width || !fabricCanvas.height) return;

			const canvasWidth = fabricCanvas.width;
			const canvasHeight = fabricCanvas.height;
			const padding = 10; // padding from the edges
			let fontSize = 32;
			let letterSpacing = fontSize;
			let charsPerLine = Math.floor((canvasWidth - 2 * padding) / letterSpacing);

			// Adjust font size and spacing if needed to fit within the canvas
			while (
				($currentFlashcard.length / charsPerLine) * letterSpacing + 2 * padding > canvasHeight &&
				fontSize > 12
			) {
				fontSize -= 1;
				letterSpacing = fontSize;
				charsPerLine = Math.floor((canvasWidth - 2 * padding) / letterSpacing);
			}

			// Calculate the starting Y position to vertically center the text block
			const totalLines = Math.ceil($currentFlashcard.length / charsPerLine);
			const startY = padding;

			// Skip last 2 canvases
			if (i < NUM_OF_THUMBAILS - 2) {
				$currentFlashcard.split('').forEach((char, index) => {
					if (!fabricCanvas.width || !fabricCanvas.height) return;

					// Calculate which line and column this character should be on
					const line = Math.floor(index / charsPerLine);
					const column = index % charsPerLine;

					// Calculate the horizontal start of this line
					const startX =
						fabricCanvas.width / 2 -
						(Math.min($currentFlashcard.length - line * charsPerLine, charsPerLine) *
							letterSpacing) /
							2;

					// Position each letter in the grid
					const text = new fabric.Text(char, {
						left: startX + column * letterSpacing,
						top: startY + line * letterSpacing,
						fontSize: fontSize,
						fill: 'black',
						opacity: 0.3,
						selectable: true,
					});

					fabricCanvas.add(text);
				});
				fabricCanvas.renderAll();
			}

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
						fabricCanvas.getHeight() - (obj.getBoundingRect().height ?? 0),
					);
					obj.left = Math.min(obj.left, fabricCanvas.getWidth() - obj.getBoundingRect().width);
					obj.top = Math.max(obj.top, 0);
					obj.left = Math.max(obj.left, 0);
				}
			});

			window.addEventListener('resize', handleResize);
			fabricCanvas.on('object:added', saveDrawing);
			fabricCanvas.on('object:added', updateSavedDrawings);
			fabricCanvasMap.set(`${$page.params.slug}-${currentIndex}-${i}`, fabricCanvas);
		}

		// Set current fabric canvas to the first one
		fabricCanvas = fabricCanvasMap.get(canvasId);
	};

	function handleResize() {
		fabricCanvas.setWidth(width);
		fabricCanvas.setHeight(height);
		fabricCanvas.renderAll();
	}

	function clearFabricCanvas() {
		fabricCanvas.clear();
		saveDrawing();
	}

	function removeLastStroke() {
		const objects = fabricCanvas.getObjects();
		if (objects.length > 0) {
			fabricCanvas.remove(objects[objects.length - 1]);
			saveDrawing();
			updateSavedDrawings();
		}
	}

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

	onDestroy(() => {
		window.removeEventListener('resize', handleResize);
	});

	// Get canvas
	onMount(() => {
		loadDrawing(canvasId);
		updateSavedDrawings();
		initializeFabricCanvas();
	});

	$: if (canvasCarouselApi) {
		loadDrawing(canvasId);

		canvasCarouselApi.on('select', () => {
			current = canvasCarouselApi.selectedScrollSnap();
			canvasId = `${$page.params.slug}-${currentIndex}-${current}`;
			// update canvas and context
			fabricCanvas = fabricCanvasMap.get(canvasId);

			updateSavedDrawings();
		});
	}

	$: if (imageCarouselApi && canvasCarouselApi) {
		imageCarouselApi.on('select', () => {
			canvasCarouselApi.scrollTo(imageCarouselApi.selectedScrollSnap());
		});

		addThumbBtnsClickHandlers();
	}

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
	<Tooltip.Root>
		<Tooltip.Trigger>
			<button
				on:click={() => ($canIdrawMultipleTimes = false)}
				class="block rounded-full border bg-white p-2 shadow-sm transition-all"
			>
				<FileText class="size-5" />
			</button>
		</Tooltip.Trigger>
		<Tooltip.Content>
			<p>Back to Flashcard</p>
		</Tooltip.Content>
	</Tooltip.Root>

	<Tooltip.Root>
		<Tooltip.Trigger>
			<button
				on:click={() => (isDrawingMode = !isDrawingMode)}
				class="block rounded-full border bg-white p-2 shadow-sm transition-all"
			>
				{#if isDrawingMode}
					<PenTool class="size-5" />
				{:else}
					<Hand class="size-5" />
				{/if}
			</button>
		</Tooltip.Trigger>
		<Tooltip.Content>
			<p>{isDrawingMode ? 'Drawing Mode' : 'Move Mode'}</p>
		</Tooltip.Content>
	</Tooltip.Root>

	<Tooltip.Root>
		<Tooltip.Trigger>
			<button
				on:click={removeLastStroke}
				class="block rounded-full border bg-white p-2 shadow-sm transition-all"
			>
				<Undo2 class="size-5" />
			</button>
		</Tooltip.Trigger>
		<Tooltip.Content>
			<p>Undo</p>
		</Tooltip.Content>
	</Tooltip.Root>

	<Tooltip.Root>
		<Tooltip.Trigger>
			<button
				on:click|preventDefault={clearFabricCanvas}
				class="block rounded-full border bg-white p-2 shadow-sm transition-all"
			>
				<CircleX class="size-5" />
			</button>
		</Tooltip.Trigger>
		<Tooltip.Content>
			<p>Clear All</p>
		</Tooltip.Content>
	</Tooltip.Root>
</div>

<Carousel.Root
	bind:api={canvasCarouselApi}
	opts={{
		watchDrag: false,
	}}
	class="w-full"
>
	<Carousel.Content>
		{#each Array(NUM_OF_THUMBAILS) as _, i (i)}
			<Carousel.Item>
				<div style="perspective: 3000px;" class="mx-auto w-fit">
					<canvas
						id={`${$page.params.slug}-${currentIndex}-${i}`}
						{width}
						{height}
						class={cn(
							'relative z-10 mx-auto block cursor-pointer rounded-xl border shadow-sm bg-dotted-spacing-8 bg-dotted-gray-200',
							rotationY > 90 && 'hidden',
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
		dragFree: true,
	}}
	class="flex w-full justify-center"
>
	<Carousel.Content class="flex gap-4 md:gap-10">
		{#each savedDrawings as src, i (i)}
			<Carousel.Item
				class={cn(
					'flex basis-auto cursor-pointer items-center justify-center  border border-transparent pl-0',
					i === current && 'rounded-lg border border-primary',
				)}
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
