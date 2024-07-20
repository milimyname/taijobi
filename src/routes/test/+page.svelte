<script lang="ts">
	import { onMount } from 'svelte';
	import { fabric } from 'fabric';

	let canvas: fabric.Canvas;
	let drawingMode = false;
	let drawingLineWidth = 1;

	const initializeCanvas = () => {
		canvas = new fabric.Canvas('c', {
			isDrawingMode: drawingMode,
		});

		fabric.Object.prototype.transparentCorners = false;
	};

	const toggleDrawingMode = () => {
		drawingMode = !drawingMode;
		if (canvas) canvas.isDrawingMode = drawingMode;
	};

	onMount(() => {
		initializeCanvas();
	});
</script>

<div>
	<button id="drawing-mode" on:click={toggleDrawingMode}>
		{drawingMode ? 'Cancel drawing mode' : 'Enter drawing mode'}
	</button>
	<!-- <div id="drawing-mode-options">
		<label for="drawing-line-width">Line width:</label>
		<input type="range" id="drawing-line-width" min="1" max="100" bind:value={drawingLineWidth} />
	</div> -->
	<canvas id="c" width="800" height="600"></canvas>
</div>
