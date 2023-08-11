<script lang="ts">
	import { kanjiStore } from './../../../lib/utils/stores.ts';
	import { onMount } from 'svelte';
	import {
		progressSlider,
		currentLetter,
		hiraganaStore,
		katakanaStore,
		currentAlphabet
	} from '$lib/utils/stores';
	import { cubicOut } from 'svelte/easing';
	import { tweened } from 'svelte/motion';
	import { icons } from '$lib/utils/icons';
	import { clearCanvas } from '$lib/utils/actions';
	import { toRomaji } from 'wanakana';
	import { goto } from '$app/navigation';
	import { page } from '$app/stores';
	import Letter from '../Letter.svelte';
	import Canvas from '../Canvas.svelte';

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
			lineJoin: string;
			lineCap: string;
		};

	// Get the last segment of the URL path (assuming it contains the identifier you need)
	$currentAlphabet = $page.url.pathname.split('/').pop() as 'hiragana' | 'katakana' | 'kanji';

	// Get the alphabet store length
	let alphabetLengh: number;
	$: switch ($currentAlphabet) {
		case 'katakana':
			alphabetLengh = $katakanaStore.length;
			break;
		case 'kanji':
			alphabetLengh = $kanjiStore.length;
			break;
		default:
			alphabetLengh = $hiraganaStore.length;
	}

	// Get canvas and context
	onMount(() => {
		canvas = document.querySelector('canvas');
		ctx = canvas.getContext('2d');
	});
</script>

<section class="flex flex-1 flex-col justify-center gap-3 sm:gap-10">
	<button
		on:click={() => {
			goto('/alphabets');
		}}
		class="flex items-center gap-2 sm:hidden"
	>
		{@html icons.previous}
		<span>Back</span>
	</button>
	<Letter rotationY={$rotateYCard} />
	<div style="perspective: 3000px; position: relative;" class="mb-10">
		<Canvas rotationY={$rotateYCard} {canvas} {ctx} />

		<div
			style={`transform: rotateY(${180 - $rotateYCard}deg); backface-visibility: hidden;`}
			class="relative z-10 mx-auto
				{$rotateYCard > 90 ? 'block' : 'hidden'} 
				 flex h-[504px] w-[354px] flex-col items-center justify-center gap-5 rounded-xl border p-5 shadow-sm sm:h-[600px] sm:w-[600px]"
		>
			<h1 class="text-9xl font-medium">{toRomaji($currentLetter).toUpperCase()}</h1>
			<p class="text-lg">Romanji</p>
		</div>

		<span
			class=" {$rotateYCard > 40 && $rotateYCard < 175
				? 'hidden'
				: 'text-black'}  fixed right-5 top-5 z-30 text-lg font-medium md:right-40 lg:right-96"
		>
			{Math.floor($progressSlider)}
		</span>

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
				$progressSlider < alphabetLengh ? $progressSlider++ : $progressSlider;
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
			}}
		>
			{@html icons.backside}
		</button>
	</div>
</section>
