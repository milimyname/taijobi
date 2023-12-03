<script lang="ts">
	import {
		canvasLgHeight,
		canvasLgWidth,
		canvasSmWidth,
		canvasSmHeight
	} from '$lib/utils/constants';
	import type { Ctx } from '$lib/utils/ambient.d.ts';
	import { twSmallScreen, xmSmallScreen } from '$lib/utils/constants';
	import { innerWidthStore, lastPoint, strokeColor } from '$lib/utils/stores';
	import { onMount } from 'svelte';

	export let rotationY: number;
	export let canvas: HTMLCanvasElement;
	export let ctx: Ctx;

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
	onMount(() => {
		ctx = canvas.getContext('2d') as Ctx;
		ctx.lineWidth = $innerWidthStore > twSmallScreen ? 12 : 10;
		ctx.lineJoin = 'round'; // Set the line join property
		ctx.lineCap = 'round'; // Set the line cap property
	});

	$: if (ctx) {
		ctx.lineWidth = $innerWidthStore > twSmallScreen ? 12 : 10;
		ctx.lineJoin = 'round';
		ctx.lineCap = 'round';
	}
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
	width={$innerWidthStore > twSmallScreen
		? canvasLgWidth
		: $innerWidthStore < xmSmallScreen
		? canvasSmWidth
		: canvasSmWidth}
	height={$innerWidthStore > twSmallScreen
		? canvasLgHeight
		: $innerWidthStore < xmSmallScreen
		? canvasSmHeight
		: window.innerHeight * 0.6}
	style={`transform: rotateY(${-rotationY}deg); transform-style: preserve-3d; backface-visibility: hidden;`}
	class="relative z-10 mx-auto cursor-pointer
				{rotationY > 90 ? 'hidden' : 'block'} 
			 rounded-xl border shadow-sm bg-dotted-spacing-8 bg-dotted-gray-200"
/>
