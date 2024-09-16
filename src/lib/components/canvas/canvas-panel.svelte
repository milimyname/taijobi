<script lang="ts">
	import { clearCanvas, redrawCanvas } from '$lib/utils/actions';
	import { animateSVG, strokes, showLetterDrawing } from '$lib/utils/stores';
	import { Undo2, Eraser, RefreshCcw, FileText } from 'lucide-svelte';
	import * as Tooltip from '$lib/components/ui/tooltip';
	import { Button } from '$lib/components/ui/button/';

	export let canvas: HTMLCanvasElement;
	export let showAnimation: boolean = true;
	export let customUndoLastStroke = () => {};

	function undoLastStroke() {
		if ($strokes.length > 0) {
			$strokes.pop();
			redrawCanvas(canvas);
		}
		if (customUndoLastStroke) customUndoLastStroke();
	}

	function removeEverything() {
		clearCanvas(canvas);
	}
</script>

<div class="flex items-center justify-center sm:mx-auto lg:-order-1">
	<slot name="find" />

	<div class="flex items-center justify-between gap-8 rounded-full bg-black px-4 py-2 text-white">
		<Tooltip.Root>
			<Tooltip.Trigger>
				<Button variant="none" size="icon" class="flex items-center" on:click={undoLastStroke}>
					<Undo2 class="size-5" />
				</Button>
			</Tooltip.Trigger>
			<Tooltip.Content>
				<p>Undo last stroke</p>
			</Tooltip.Content>
		</Tooltip.Root>
		<slot name="remove">
			<Tooltip.Root>
				<Tooltip.Trigger>
					<Button variant="none" size="icon" class="flex items-center" on:click={removeEverything}>
						<Eraser class="size-5" />
					</Button>
				</Tooltip.Trigger>
				<Tooltip.Content>
					<p>Clear</p>
				</Tooltip.Content>
			</Tooltip.Root>
		</slot>
		{#if showAnimation}
			<Tooltip.Root>
				<Tooltip.Trigger>
					<Button
						variant="none"
						size="icon"
						class="flex items-center"
						on:click={() => {
							$animateSVG = !$animateSVG;
							// setTimeout(() => ($animateSVG = true), 250);
						}}
					>
						<RefreshCcw class="size-5" />
					</Button>
				</Tooltip.Trigger>
				<Tooltip.Content>
					<p>Animate</p>
				</Tooltip.Content>
			</Tooltip.Root>
		{/if}

		<Tooltip.Root>
			<Tooltip.Trigger>
				<Button
					variant="none"
					size="icon"
					class="flex items-center"
					on:click={() => ($showLetterDrawing = false)}
				>
					<FileText class="size-5" />
				</Button>
			</Tooltip.Trigger>
			<Tooltip.Content>
				<p>Return to flashcard</p>
			</Tooltip.Content>
		</Tooltip.Root>
	</div>
</div>
