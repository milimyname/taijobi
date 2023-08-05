<script lang="ts">
	import { twSmallScreen } from '$lib/utils/constants';
	import { onMount } from 'svelte';
	import { innerWidthStore } from '$lib/utils/stores';
	import { draw } from 'svelte/transition';
	import { quintOut, cubicOut } from 'svelte/easing';
	import { tweened } from 'svelte/motion';

	const rotateYCard = tweened(0, {
		duration: 2000,
		easing: cubicOut
	});

	let canvas: HTMLCanvasElement,
		ctx: {
			strokeStyle: string;
			beginPath: () => void;
			moveTo: (arg0: number, arg1: number) => void;
			lineTo: (arg0: number, arg1: number) => void;
			stroke: () => void;
			lineWidth: number;
		};
	let isDrawing = false;
	let lastPoint = { x: 0, y: 0 };
	let strokeColor = 'black'; // You can set the initial color here

	function startDrawing(event: any) {
		isDrawing = true;
		lastPoint = getXY(event);
		event.preventDefault();
	}

	function stopDrawing() {
		isDrawing = false;
	}

	function drawOnCanvas(event: any) {
		if (!isDrawing) return;
		ctx.beginPath();
		ctx.moveTo(lastPoint.x, lastPoint.y);
		let currentPoint = getXY(event);
		ctx.lineTo(currentPoint.x, currentPoint.y);

		ctx.strokeStyle = strokeColor; // Set the stroke color
		ctx.stroke();
		lastPoint = currentPoint;
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

	let animateSVG: boolean = true;

	function clearCanvas() {
		// Clear the entire canvas
		ctx.clearRect(0, 0, canvas.width, canvas.height);

		// Reset the lastPoint
		lastPoint = { x: 0, y: 0 };
	}

	// Initialize the context when canvas is defined
	onMount(() => {
		ctx = canvas.getContext('2d');
		ctx.lineWidth = 10;
		ctx.lineJoin = 'round'; // Set the line join property
		ctx.lineCap = 'round'; // Set the line cap property
	});
</script>

<section class="flex flex-1 flex-col justify-around sm:gap-10">
	<!-- <div class=" flex items-center justify-around">
		<input type="color" bind:value={strokeColor} />
		<button on:click={clearCanvas}> Clear Canvas</button>
		<button on:click={() => (animateSVG = !animateSVG)}>Show Character</button>
	</div> -->

	<svg
		xmlns="http://www.w3.org/2000/svg"
		viewBox="0 0 77 76"
		fill="none"
		class="absolute left-1/2 top-1/2 {$rotateYCard > 30
			? 'hidden'
			: 'block'}  h-80 w-80 -translate-x-1/2 -translate-y-1/2 opacity-20 sm:-translate-y-1/2"
	>
		{#if animateSVG}
			<path
				d="M28.5249 5.4198C28.6638 19.4501 25.5701 50.8744 25.6535 69.6317"
				stroke="black"
				stroke-width="3"
				stroke-linecap="round"
				stroke-linejoin="round"
				transition:draw={{ duration: 1000, delay: 0, easing: quintOut }}
			/>
			<path
				d="M11.7225 21.1353C16.9836 20.9184 26.5796 24.8697 26.5796 24.8697L5.75098 64.4155C5.75098 64.4155 36.2774 14.7086 58.7853 15.3621C76.5785 15.8789 74.902 64.7212 56.553 70.1476"
				stroke="black"
				stroke-width="3"
				stroke-linecap="round"
				stroke-linejoin="round"
				transition:draw={{ duration: 2000, delay: 500, easing: quintOut }}
			/>
		{/if}
	</svg>

	<div style="perspective: 3000px; position: relative;">
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
			width={$innerWidthStore > twSmallScreen ? 600 : 352}
			height={$innerWidthStore > twSmallScreen ? 600 : 502}
			style={`transform: rotateY(${-$rotateYCard}deg); transform-style: preserve-3d; backface-visibility: hidden;`}
			class="relative z-10 mx-auto cursor-pointer
				{$rotateYCard > 90 ? 'hidden' : 'block'} 
			 rounded-xl border shadow-sm bg-dotted-spacing-8 bg-dotted-gray-200"
		/>

		<div
			style={`transform: rotateY(${180 - $rotateYCard}deg); backface-visibility: hidden;`}
			class="relative z-10 mx-auto
				{$rotateYCard > 90 ? 'block' : 'hidden'} 
				h-[504px] w-[354px] rounded-xl border bg-blue-200 shadow-sm sm:h-[600px] sm:w-[600px]"
		>
			<h1 class="text-3xl font-bold">Back Side</h1>
			<p class="text-xl">Coming Soon</p>
		</div>

		<button
			class="fixed bottom-5 right-5 z-30 rounded-full border bg-white p-2 shadow-sm transition-all md:right-40 lg:right-96"
			on:click={() => {
				$rotateYCard < 40 ? rotateYCard.set(180) : rotateYCard.set(0);
				animateSVG = !animateSVG;
			}}
		>
			<svg
				xmlns="http://www.w3.org/2000/svg"
				fill="none"
				viewBox="0 0 24 24"
				stroke-width="1.5"
				stroke="currentColor"
				class="h-5 w-5"
			>
				<path
					stroke-linecap="round"
					stroke-linejoin="round"
					d="M9 15L3 9m0 0l6-6M3 9h12a6 6 0 010 12h-3"
				/>
			</svg>
		</button>
	</div>
</section>
