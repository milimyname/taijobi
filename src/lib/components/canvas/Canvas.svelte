<script lang="ts">
	import type { Ctx } from '$lib/utils/ambient.d.ts';
	import { IS_DESKTOP } from '$lib/utils/constants';
	import { innerWidthStore, lastPoint, strokeColor, innerHeightStore } from '$lib/utils/stores';
	import { onMount } from 'svelte';
	import { cn, getFlashcardHeight, getFlashcardWidth } from '$lib/utils';

	export let rotationY: number = 0;
	export let canvas: HTMLCanvasElement;
	export let ctx: Ctx;
	let isDrawing = false;
	let strokes: { points: { x: number; y: number }[]; color: string }[] = [];

	function startDrawing(event: MouseEvent | TouchEvent) {
		isDrawing = true;
		strokes.push({ points: [getXY(event)], color: $strokeColor });
		event.preventDefault();
	}

	function stopDrawing() {
		isDrawing = false;
	}

	function drawOnCanvas(event: MouseEvent | TouchEvent) {
		if (!isDrawing) return;
		const currentStroke = strokes[strokes.length - 1];
		const newPoint = getXY(event);
		currentStroke.points.push(newPoint);

		redrawCanvas();
	}

	function getXY(event: any) {
		const rect = canvas.getBoundingClientRect();
		const clientX = 'touches' in event ? event.touches[0].clientX : event.clientX;
		const clientY = 'touches' in event ? event.touches[0].clientY : event.clientY;
		return {
			x: clientX - rect.left,
			y: clientY - rect.top
		};
	}

	function redrawCanvas() {
		ctx.clearRect(0, 0, canvas.width, canvas.height); // Clear the canvas
		for (let stroke of strokes) {
			ctx.beginPath();
			for (let i = 0; i < stroke.points.length; i++) {
				const point = stroke.points[i];
				if (i === 0) {
					ctx.moveTo(point.x, point.y);
				} else {
					ctx.lineTo(point.x, point.y);
				}
			}
			ctx.strokeStyle = stroke.color;
			ctx.stroke();
		}
	}

	function undoLastStroke() {
		if (strokes.length > 0) {
			strokes.pop();
			redrawCanvas();
		}
	}

	onMount(() => {
		ctx = canvas.getContext('2d') as Ctx;
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
<!-- <button on:click={undoLastStroke} class="mt-2 rounded bg-red-500 p-2 text-white">
	Undo Last Stroke
</button> -->
