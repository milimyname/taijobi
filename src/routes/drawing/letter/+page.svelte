<script lang="ts">
	import { twSmallScreen } from '$lib/utils/constants';
	import { onMount } from 'svelte';
	import {
		innerWidthStore,
		animateSVG,
		lastPoint,
		strokeColor,
		progressSlider,
		currentHiragana,
		hiraganaStore
	} from '$lib/utils/stores';
	import { cubicOut } from 'svelte/easing';
	import { tweened } from 'svelte/motion';
	import Letter from '../Letter.svelte';
	import { icons } from '$lib/utils/icons';
	import { clearCanvas } from '$lib/utils/actions';
	import { toRomaji } from 'wanakana';

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
	// You can set the initial color here

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

	// Initialize the context when canvas is defined
	onMount(() => {
		ctx = canvas.getContext('2d');
		ctx.lineWidth = $innerWidthStore > twSmallScreen ? 15 : 10;
		ctx.lineJoin = 'round'; // Set the line join property
		ctx.lineCap = 'round'; // Set the line cap property
	});
</script>

<section class="flex flex-1 flex-col justify-around sm:gap-10">
	<Letter rotationY={$rotateYCard} />
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
				 flex h-[504px] w-[354px] flex-col items-center justify-center gap-5 rounded-xl border p-5 shadow-sm sm:h-[600px] sm:w-[600px]"
		>
			<h1 class="text-9xl font-medium">{toRomaji($currentHiragana).toUpperCase()}</h1>
			<p class="text-lg">Romanji</p>
		</div>

		<p
			class=" {$rotateYCard > 40 && $rotateYCard < 175
				? 'hidden'
				: 'text-black'}  fixed right-5 top-5 z-30 text-lg font-medium md:right-40 lg:right-96"
		>
			{Math.floor($progressSlider)}
		</p>

		<button
			on:click|preventDefault={() => {
				clearCanvas(ctx, canvas);
				$progressSlider > 1 ? $progressSlider-- : $progressSlider;
			}}
			class="previousLetter fixed -bottom-10 z-30 rounded-full border bg-white p-2 shadow-sm transition-all lg:left-[22rem]"
		>
			{@html icons.previous}
		</button>

		<button
			on:click|preventDefault={() => {
				clearCanvas(ctx, canvas);
				$progressSlider < $hiraganaStore.length ? $progressSlider++ : $progressSlider;
			}}
			class="previousLetter fixed -bottom-10 right-0 z-30 rounded-full border bg-white p-2 shadow-sm transition-all lg:right-[22rem]"
		>
			{@html icons.next}
		</button>

		<button
			class="{$rotateYCard > 40 && $rotateYCard < 175 ? 'hidden' : 'block'}
				fixed bottom-5 right-5 z-30 rounded-full border bg-white p-2 shadow-sm transition-all md:right-40 lg:right-96"
			on:click={() => {
				$rotateYCard < 40 ? rotateYCard.set(180) : rotateYCard.set(0);
				$animateSVG = !$animateSVG;
			}}
		>
			{@html icons.backside}
		</button>
	</div>
</section>
