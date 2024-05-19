<script lang="ts">
	import { IS_DESKTOP } from '$lib/utils/constants';
	import { innerWidthStore, lastPoint, strokeColor, innerHeightStore } from '$lib/utils/stores';
	import { onMount } from 'svelte';
	import { cn, getFlashcardHeight, getFlashcardWidth } from '$lib/utils';

	export let rotationY: number = 0;
	export let canvas: HTMLCanvasElement;
	export let canvasId: string = '';

	let ctx: CanvasRenderingContext2D;
	let isDrawing = false;

	function startDrawing(event: any) {
		isDrawing = true;

		$lastPoint = getXY(event);
		event.preventDefault();
	}

	function stopDrawing() {
		isDrawing = false;
	}

	function drawOnCanvas(event: any) {
		if (!isDrawing) return;
		ctx.beginPath();
		ctx.moveTo($lastPoint.x, $lastPoint.y);
		let currentPoint = getXY(event);
		ctx.lineTo(currentPoint.x, currentPoint.y);

		ctx.strokeStyle = $strokeColor; // Set the stroke color
		ctx.stroke();
		$lastPoint = currentPoint;
	}

	function getXY(event: any) {
		let rect = canvas.getBoundingClientRect();
		if (event.touches) {
			// If it is a touch event
			return {
				x: event.touches[0].clientX - rect.left,
				y: event.touches[0].clientY - rect.top
			};
		} else {
			// If it is a mouse event
			return {
				x: event.clientX - rect.left,
				y: event.clientY - rect.top
			};
		}
	}

	function saveDrawing() {
		localStorage.setItem(canvasId, canvas.toDataURL());
	}

	onMount(() => {
		ctx = canvas.getContext('2d') as CanvasRenderingContext2D;
		ctx.lineWidth = $innerWidthStore > IS_DESKTOP ? 12 : 10;
		ctx.lineJoin = 'round'; // Set the line join property
		ctx.lineCap = 'round'; // Set the line cap property
	});

	$: if (ctx) {
		ctx.lineWidth = $innerWidthStore > IS_DESKTOP ? 12 : 10;
		ctx.lineJoin = 'round';
		ctx.lineCap = 'round';
	}

	// Skeleton sizes for the flashcard
	let width = 350;
	let height = 400;

	$: if ($innerWidthStore) width = getFlashcardWidth($innerWidthStore);
	$: if ($innerHeightStore) height = getFlashcardHeight($innerWidthStore, $innerHeightStore);
</script>

<canvas
	bind:this={canvas}
	on:mousedown={startDrawing}
	on:mouseup={stopDrawing}
	on:mousemove|preventDefault={drawOnCanvas}
	on:mouseleave={stopDrawing}
	on:touchstart={startDrawing}
	on:touchend={stopDrawing}
	on:touchmove|preventDefault={drawOnCanvas}
	on:touchcancel={stopDrawing}
	{width}
	{height}
	style={`transform: rotateY(${-rotationY}deg); transform-style: preserve-3d; backface-visibility: hidden;`}
	class={cn(
		'relative z-10 mx-auto block cursor-pointer rounded-xl border shadow-sm bg-dotted-spacing-8 bg-dotted-gray-200',
		rotationY > 90 && 'hidden'
	)}
/>
