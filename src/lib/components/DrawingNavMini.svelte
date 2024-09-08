<script lang="ts">
	import { animateSVG, strokes, selectedLetter } from '$lib/utils/stores';
	import { clearCanvas, redrawCanvas } from '$lib/utils/actions';
	import { onMount } from 'svelte';
	import { RefreshCcw, Undo2 } from 'lucide-svelte';
	import { cn } from '$lib/utils';
	import { Button } from '$lib/components/ui/button';
	import handwriting from '$lib/utils/handwriting.js';
	import { toast } from 'svelte-sonner';
	import { isJapanese } from 'wanakana';
	import { ScrollArea } from '$lib/components/ui/scroll-area';
	import { slide } from 'svelte/transition';

	export let className = '';
	export let nextStep: () => void;

	let recognizedLetters: string[] = [];
	let canvas: HTMLCanvasElement;
	let handwritingInstance: any;
	let isCorrect = false;

	function undoLastStroke() {
		if ($strokes.length > 0) {
			$strokes.pop();
			redrawCanvas(canvas);
		}
	}

	// Function to trigger handwriting recognition
	function recognize() {
		return new Promise(async (resolve, reject) => {
			try {
				// Get the image data URL from the temporary canvas
				const image = canvas.toDataURL('image/png');

				if (image.endsWith('qAAAAAElFTkSuQmCC')) return reject('No image to process');

				handwritingInstance.recognize(
					handwritingInstance.trace,
					{ language: 'ja' },
					(results: string[], error: string) => {
						if (error) {
							console.error('Recognition error:', error);
							reject(error); // Reject the promise with an error message on failure
						} else {
							recognizedLetters = [
								...recognizedLetters,
								...results.filter((letter) => isJapanese(letter)),
							].slice(0, 3); // Get only the first 3 recognized Japanese characters
							resolve(results); // Resolve the promise with the recognition results on success
						}
					},
				);
			} catch (err) {
				const message = err instanceof Error ? err.message : 'An error occurred';
				reject(message);
			}
		});
	}

	function findKanji() {
		toast.promise(recognize(), {
			loading: 'Processing image...',
			success: 'Successfully recognized it!',
			error: 'Failed to recognize the character. Please try again.',
		});
	}

	// Get canvas and context
	onMount(() => {
		canvas = document.querySelector('canvas') as HTMLCanvasElement;

		if (canvas) {
			handwritingInstance = new handwriting.Canvas(canvas, 'light');

			// Example: Set up a callback to do something when the canvas is clicked
			handwritingInstance.setCallBack((results: string[], error: string[]) => {
				if (error) console.error('Handwriting recognition error:', error);
				else console.log('Handwriting recognition results:', results);
			});
		}
	});

	// Check if it got found
	$: if (recognizedLetters.length > 0 && $selectedLetter) {
		if (recognizedLetters.includes($selectedLetter?.name)) {
			toast.success('Correct!', {
				description: 'Please choose one of the options below.',
			});
			isCorrect = true;
		} else {
			toast.error('Incorrect!', {
				description: `Please try to draw the letter ${$selectedLetter?.name} again.`,
			});
			clearCanvas(canvas);
			isCorrect = false;
			recognizedLetters = [];
			handwritingInstance.erase();
		}
	}
</script>

<slot />

<div class="mt-4 h-10">
	{#if recognizedLetters.length > 0 && isCorrect}
		<div in:slide={{ duration: 300 }}>
			<ScrollArea class="overflow-y-visible whitespace-nowrap" orientation="horizontal">
				<div class="flex w-max gap-4">
					{#each recognizedLetters as letter}
						<Button
							variant="ghost"
							class="relative flex flex-col rounded-md border"
							on:click={nextStep}
						>
							<span class="text-2xl font-bold">{letter}</span>
						</Button>
					{/each}
				</div>
			</ScrollArea>
		</div>
	{/if}
</div>

<nav class={cn('mx-auto flex h-14 w-20 select-none items-center justify-center gap-2', className)}>
	<Button variant="outline" size="sm" on:click={undoLastStroke}>
		<Undo2 class="size-5" />
	</Button>

	<Button variant="outline" size="sm" on:click={() => ($animateSVG = !$animateSVG)}>
		<RefreshCcw class="size-5 transition-transform active:rotate-180" />
	</Button>

	{#if $strokes?.length > 0 && recognizedLetters.length === 0}
		<Button on:click={findKanji}>Done?</Button>
	{/if}
</nav>
