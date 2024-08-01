<script lang="ts">
	import { clearCanvas, redrawCanvas } from '$lib/utils/actions';
	import { animateSVG, strokes, showLetterDrawing } from '$lib/utils/stores';
	import { Undo2, Eraser, RefreshCcw, FileText } from 'lucide-svelte';

	export let canvas: HTMLCanvasElement;
	export let showAnimation: boolean = true;

	function undoLastStroke() {
		if ($strokes.length > 0) {
			$strokes.pop();
			redrawCanvas(canvas);
		}
	}

	function removeEverything() {
		clearCanvas(canvas);
	}
</script>

<div class="flex items-center justify-center sm:mx-auto lg:-order-1">
	<slot name="find" />

	<div class="flex items-center justify-between gap-8 rounded-full bg-black px-4 py-2 text-white">
		<button on:click|preventDefault={undoLastStroke}>
			<Undo2 class="size-4" />
		</button>
		<slot name="remove">
			<button on:click|preventDefault={removeEverything}>
				<Eraser class="size-4" />
			</button>
		</slot>
		{#if showAnimation}
			<button
				on:click|preventDefault={() => {
					$animateSVG = !$animateSVG;
					// setTimeout(() => ($animateSVG = true), 250);
				}}
				class="transition-transform active:rotate-180"
			>
				<RefreshCcw class="size-4" />
			</button>
		{/if}
		<button on:click={() => ($showLetterDrawing = false)}>
			<FileText class="size-4" />
		</button>
	</div>
</div>
