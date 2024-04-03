<script lang="ts">
	import { onMount } from 'svelte';
	import type { Ctx } from '$lib/utils/ambient.d.ts';
	import Canvas from '$lib/components/canvas/Canvas.svelte';
	import { createWorker } from 'tesseract.js';
	import { clearCanvas } from '$lib/utils/actions';
	import { CircleX, CirclePlus } from 'lucide-svelte';

	// export let data;

	let canvas: HTMLCanvasElement;
	let ctx: Ctx;
	let recognizedLetters: string[] = [];

	// Get canvas and context
	onMount(() => {
		canvas = document.querySelector('canvas') as HTMLCanvasElement;
		ctx = canvas.getContext('2d') as Ctx;
	});

	// async function logTesseract() {
	// 	const worker = await createWorker('eng');
	// 	const ret = await worker.recognize('https://tesseract.projectnaptha.com/img/eng_bw.png');
	// 	console.log(ret.data.text);
	// 	await worker.terminate();
	// }

	//  Capture canvas to image
	async function performOCR() {
		const image = canvas.toDataURL('image/png');

		// const worker = await createWorker('jpn', 1, {
		// 	logger: (m) => console.log(m)
		// });
		const worker = await createWorker('jpn', 1);

		try {
			const {
				data: { text }
			} = await worker.recognize(image);
			recognizedLetters = [...recognizedLetters, text];
		} catch (error) {
			console.error('OCR error:', error);
		}

		await worker.terminate();
	}
</script>

<section class="flex h-full flex-col gap-4 sm:gap-5 lg:justify-center">
	<div class="flex gap-2">
		{#each recognizedLetters as letter}
			<p class="text-xl">{letter}</p>
		{/each}
	</div>
	<div style="perspective: 3000px;" class="my-auto lg:my-0">
		<div>
			<Canvas {canvas} {ctx} />

			<button
				on:click|preventDefault={() => clearCanvas(ctx, canvas)}
				class="fixed bottom-5 left-5 z-30 block rounded-full border bg-white p-2 shadow-sm transition-all"
			>
				<CircleX />
			</button>

			<button
				on:click={performOCR}
				class="fixed bottom-5 right-5 z-30 block rounded-full border bg-white p-2 shadow-sm transition-all"
			>
				<CirclePlus />
			</button>
		</div>
	</div>
</section>
