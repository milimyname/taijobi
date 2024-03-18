<script lang="ts">
	import type { FlashcardType } from '$lib/utils/ambient.d.ts';
	import { kanji } from '$lib/static/kanji';
	import { fly } from 'svelte/transition';
	import {
		currentAlphabet,
		currentFlashcard,
		showLetterDrawing,
		showProgressSlider,
		innerHeightStore,
		innerWidthStore,
		currentFlashcardTypeStore
	} from '$lib/utils/stores';
	import { quintOut, cubicOut } from 'svelte/easing';
	import { tweened } from 'svelte/motion';
	import { RotateCcw, Box, PenTool, Volume2 } from 'lucide-svelte';
	import { cn, getFlashcardHeight, getFlashcardWidth, isNonJapanase } from '$lib/utils';
	import { browser } from '$app/environment';
	import { replaceStateWithQuery } from '$lib/utils';
	import CustomCompletion from './custom-completion.svelte';
	import { clickOutside } from '$lib/utils/clickOutside';

	export let wordFlashcard: FlashcardType | undefined;
	export let currentFlashcardFurigana: string;
	export let currentIndex: number;
	export let longWord: boolean;

	const rotateYCard = tweened(0, {
		duration: 2000,
		easing: cubicOut
	});
	let showCustomContent: boolean = false;
	let kanjiFlashcard: FlashcardType;
	let audioSource = '';
	let audioElement: HTMLAudioElement;

	$: if (!isNonJapanase($currentFlashcard) && $currentFlashcardTypeStore === 'kanji')
		kanjiFlashcard = kanji[$currentFlashcard];
	else if ($currentFlashcardTypeStore === 'kanji')
		kanjiFlashcard = { name: '', meaning: '', onyomi: '', kunyomi: '' };

	$: if (browser && wordFlashcard)
		replaceStateWithQuery({
			flashcardName: wordFlashcard.name,
			meaning: wordFlashcard.meaning
		});

	async function convertTextToSpeech() {
		try {
			const res = await fetch('/api/openai', {
				method: 'POST',
				headers: {
					'Content-Type': 'application/json'
				},
				body: JSON.stringify({ input: wordFlashcard?.name, type: 'audio' })
			});

			if (!res.ok) throw new Error('Failed to fetch audio');

			const data = await res.json();

			const audioData = data.audioData;

			audioSource = `data:audio/mp3;base64,${audioData}`;
		} catch (e) {
			console.error(e);
		}
	}

	$: if (wordFlashcard) audioSource = '';
</script>

{#if audioSource}
	<audio src={audioSource} bind:this={audioElement} />
{/if}

<div style="perspective: 3000px; position: relative;">
	<div
		style={`transform: rotateY(${-$rotateYCard}deg); transform-style: preserve-3d; backface-visibility: hidden; 
				height: ${getFlashcardHeight($innerWidthStore, $innerHeightStore)}px;
				width: ${getFlashcardWidth($innerWidthStore)}px `}
		class={cn(
			'relative z-10 flex cursor-pointer items-center justify-center rounded-xl border shadow-sm bg-dotted-spacing-8 bg-dotted-gray-200',
			$rotateYCard > 90 && 'hidden',
			longWord && 'py-10 sm:py-32'
		)}
	>
		{#if $currentFlashcardTypeStore === 'kanji'}
			<span class="text-9xl sm:text-[14rem]">
				{$currentFlashcard}
			</span>
		{:else if $currentFlashcardTypeStore === 'phrase'}
			<p class="text-balance px-10 text-center text-5xl leading-normal tracking-widest">
				{@html currentFlashcardFurigana}
			</p>
		{:else}
			<p class="vertical text-balance text-5xl leading-normal tracking-widest">
				{@html currentFlashcardFurigana}
			</p>
		{/if}

		<span class="fixed left-2 top-3 z-30 text-sm xm:left-5 xm:top-5">
			{currentIndex + 1}
		</span>

		<div class="flex gap-5">
			{#if !isNonJapanase($currentFlashcard)}
				<button
					class={cn(
						'absolute bottom-3 left-2 z-30 rounded-full border bg-white p-2 shadow-sm transition-all xm:bottom-5 xm:left-5',
						showCustomContent && 'hidden'
					)}
					on:click={() => {
						$showLetterDrawing = true;
						$showProgressSlider = false;
					}}
				>
					<PenTool class="size-4" />
				</button>
			{/if}

			<button
				class={cn(
					'absolute bottom-14 left-2 z-30 rounded-full border bg-white p-2 shadow-sm transition-all xm:bottom-[4rem] xm:left-5',
					showCustomContent && 'hidden'
				)}
				on:click={async () => {
					if (audioSource === '') await convertTextToSpeech();
					if (audioElement) audioElement.play();
				}}
			>
				<Volume2 class="size-4" />
			</button>
		</div>

		<button
			class="{showCustomContent && 'hidden'} 
						absolute bottom-3 right-2 z-30 rounded-full border bg-white p-2 shadow-sm transition-all xm:bottom-5 xm:right-5"
			on:click={() => ($rotateYCard < 40 ? rotateYCard.set(180) : rotateYCard.set(0))}
		>
			<RotateCcw class="size-4" />
		</button>
	</div>

	<div
		style={`transform: rotateY(${180 - $rotateYCard}deg); backface-visibility: hidden; 
				height: ${getFlashcardHeight($innerWidthStore, $innerHeightStore)}px;
				width: ${getFlashcardWidth($innerWidthStore)}px`}
		class={cn(
			'relative z-10 mx-auto justify-center overflow-hidden rounded-xl border p-5 shadow-sm sm:p-10',
			$rotateYCard > 90 ? 'block' : 'hidden',
			$currentAlphabet === 'kanji' ? 'gap-1' : 'gap-5'
		)}
	>
		{#if $currentFlashcardTypeStore === 'kanji'}
			<div
				class="grid-rows-[max-content max-content] sm:grid-rows-[max-content 1fr] grid h-full grid-cols-2 sm:gap-4"
			>
				<h2 class="col-span-2 text-center text-6xl sm:text-9xl">{$currentFlashcard}</h2>

				{#if wordFlashcard?.meaning !== ''}
					<div>
						<h4 class="text-lg">{wordFlashcard?.meaning}</h4>
						<p class="text-sm text-gray-300">Meaning</p>
					</div>
				{:else if wordFlashcard?.meaning === ''}
					<div>
						<h4 class="text-lg">-</h4>
						<p class="text-sm text-gray-300">Meaning</p>
					</div>
				{:else}
					<div>
						<h4 class="text-lg">{kanjiFlashcard.meaning}</h4>
						<p class="text-sm text-gray-300">Meaning</p>
					</div>
				{/if}

				{#if kanjiFlashcard.onyomi.length > 0}
					<div>
						<h4 class="text-lg tracking-widest">{kanjiFlashcard.onyomi}</h4>
						<p class="text-sm text-gray-300">Onyomi</p>
					</div>
				{/if}

				{#if kanjiFlashcard.kunyomi.length > 0}
					<div>
						<h4 class="text-lg tracking-widest">{kanjiFlashcard.kunyomi}</h4>
						<p class=" text-sm text-gray-300">Kunyomi</p>
					</div>
				{/if}

				{#if wordFlashcard?.notes && wordFlashcard?.notes.length > 0}
					<button
						class="fixed bottom-0 left-0 z-10 rounded-tr-xl {showCustomContent
							? 'bg-white text-black'
							: 'bg-blue-200'} p-5"
						on:click|preventDefault={() => (showCustomContent = !showCustomContent)}
					>
						<Box class="size-6" />
					</button>

					{#if showCustomContent}
						<p
							transition:fly={{
								delay: 0,
								duration: 1000,
								opacity: 0,
								y: 400,
								easing: quintOut
							}}
							class="z-4 absolute bottom-0 left-0 h-5/6 w-full rounded-xl bg-primary p-4 text-sm text-white"
						>
							{wordFlashcard.notes}
						</p>
					{/if}
				{/if}
				<button
					class="{showCustomContent && 'hidden'}
								fixed bottom-5 right-5 z-30 rounded-full border bg-white p-2 shadow-sm transition-all"
					on:click={() => ($rotateYCard < 40 ? rotateYCard.set(180) : rotateYCard.set(0))}
				>
					<RotateCcw class="size-4" />
				</button>
			</div>
		{:else}
			<div
				class="grid-rows-[max-content max-content] sm:grid-rows-[max-content 1fr] grid h-full grid-cols-2 sm:gap-4"
			>
				<h2 class="col-span-2 text-center text-4xl">{$currentFlashcard}</h2>

				{#if wordFlashcard?.meaning}
					<div>
						<h2 class="text-xl font-medium">{wordFlashcard.meaning}</h2>
						<p class=" text-sm text-gray-300">Meaning</p>
					</div>
				{/if}
				{#if wordFlashcard?.customFurigana}
					<div>
						<h2 class="text-xl font-medium">{wordFlashcard.customFurigana}</h2>
						<p class=" text-sm text-gray-300">Custom furigana</p>
					</div>
				{/if}
				{#if wordFlashcard?.romanji}
					<div class="justify-self-end sm:justify-self-start">
						<h2 class="text-xl font-medium">{wordFlashcard.romanji}</h2>
						<p class=" text-sm text-gray-300">Romanji/Furigana</p>
					</div>
				{/if}
				<button
					class="flashcard-completion-btn fixed bottom-0 left-0 z-10 rounded-tr-xl {showCustomContent
						? 'bg-white text-black'
						: 'bg-blue-200'} p-5"
					on:click|preventDefault={() => (showCustomContent = !showCustomContent)}
				>
					<Box class="size-6" />
				</button>

				{#if showCustomContent}
					<div
						use:clickOutside={() => (showCustomContent = false)}
						class="z-4 absolute bottom-0 left-0 h-5/6 w-full rounded-xl bg-primary p-4 text-xl text-white"
						transition:fly={{
							delay: 0,
							duration: 1000,
							opacity: 0,
							y: 400,
							easing: quintOut
						}}
					>
						<CustomCompletion {wordFlashcard} />
					</div>
				{/if}

				<button
					class="{showCustomContent && 'hidden'}
								fixed bottom-5 right-5 z-30 rounded-full border bg-white p-2 shadow-sm transition-all"
					on:click={() => ($rotateYCard < 40 ? rotateYCard.set(180) : rotateYCard.set(0))}
				>
					<RotateCcw class="size-4" />
				</button>
			</div>
		{/if}
	</div>
</div>

<style>
	.vertical {
		-webkit-writing-mode: vertical-rl;
		-moz-writing-mode: vertical-rl;
		-ms-writing-mode: vertical-rl;
		writing-mode: vertical-rl;
	}
</style>
