<script lang="ts">
	import { IS_DESKTOP } from '$lib/utils/constants';
	import { innerWidthStore, strokeColor, innerHeightStore } from '$lib/utils/stores';
	import { onDestroy, onMount } from 'svelte';
	import { cn, getFlashcardHeight, getFlashcardWidth } from '$lib/utils';
	import { fabric } from 'fabric';

	export let rotationY: number = 0;
	export let canvas: HTMLCanvasElement;
	export let canvasId: string = '';
	export let isDrawingMode = true;

	export let fabricCanvas: fabric.Canvas;

	// Skeleton sizes for the flashcard
	let width = 350;
	let height = 400;

	function saveDrawing() {
		localStorage.setItem(canvasId, fabricCanvas.toDataURL());
	}

	const initializeFabricCanvas = () => {
		fabricCanvas = new fabric.Canvas(canvasId, {
			isDrawingMode
		});

		fabric.Object.prototype.transparentCorners = false;

		// fabricCanvas.freeDrawingBrush.width = $innerWidthStore > IS_DESKTOP ? 12 : 10;
		// fabricCanvas.freeDrawingBrush.color = $strokeColor;

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
				obj.top = Math.min(obj.top, fabricCanvas.getHeight() - (obj.getBoundingRect().height ?? 0));
				obj.left = Math.min(obj.left, fabricCanvas.getWidth() - obj.getBoundingRect().width);
				obj.top = Math.max(obj.top, 0);
				obj.left = Math.max(obj.left, 0);
			}
		});

		window.addEventListener('resize', handleResize);
		// fabricCanvas.on('mouse:down', saveDrawing);
		// fabricCanvas.on('mouse:up', saveDrawing);
		fabricCanvas.on('object:added', saveDrawing);
	};

	function handleResize() {
		fabricCanvas.setWidth(width);
		fabricCanvas.setHeight(height);
		fabricCanvas.renderAll();
	}

	onMount(() => {
		initializeFabricCanvas();
	});

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

<canvas
	id={canvasId}
	{width}
	{height}
	class={cn(
		'relative z-10 mx-auto block cursor-pointer rounded-xl border shadow-sm bg-dotted-spacing-8 bg-dotted-gray-200',
		rotationY > 90 && 'hidden'
	)}
/>
