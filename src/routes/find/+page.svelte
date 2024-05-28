<script lang="ts">
	import { onMount } from 'svelte';
	import Canvas from '$lib/components/canvas/Canvas.svelte';
	import { clearCanvas } from '$lib/utils/actions';
	import { CircleX, CirclePlus } from 'lucide-svelte';
	import handwriting from '$lib/utils/handwriting.js';
	import { toast } from 'svelte-sonner';
	import { ScrollArea } from '$lib/components/ui/scroll-area/index';
	import { Button } from '$lib/components/ui/button';
	import { getFlashcardWidth } from '$lib/utils';
	import { innerWidthStore, searchKanji, kanjiStore, searchedWordStore } from '$lib/utils/stores';
	import { isKanji, isKatakana, isHiragana } from 'wanakana';
	import { goto } from '$app/navigation';
	import type { RecordModel } from 'pocketbase';
	import { page } from '$app/stores';

	let canvas: HTMLCanvasElement;
	let ctx: CanvasRenderingContext2D;
	let recognizedLetters: string[] = [];
	let handwritingInstance: any;

	// Get canvas and context
	onMount(() => {
		canvas = document.querySelector('canvas') as HTMLCanvasElement;
		ctx = canvas.getContext('2d') as CanvasRenderingContext2D;

		if (canvas) {
			handwritingInstance = new handwriting.Canvas(canvas, 'light');

			// Example: Set up a callback to do something when the canvas is clicked
			handwritingInstance.setCallBack((results: string[], error: string[]) => {
				if (error) console.error('Handwriting recognition error:', error);
				else console.log('Handwriting recognition results:', results);
			});
		}
	});

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
							recognizedLetters = [...recognizedLetters, ...results];
							resolve(results); // Resolve the promise with the recognition results on success
						}
					}
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
			error: 'Failed to recognize the character. Please try again.'
		});

		// Check if the recognized letter is a valid Japanese character
		recognizedLetters = recognizedLetters.filter(
			(letter) => isKanji(letter) || isKatakana(letter) || isHiragana(letter)
		);
	}

	// Fetch flashcards from the server
	async function fetchFlashcards(search: string) {
		try {
			const res = await fetch('/api/flashcard', {
				method: 'POST',
				body: JSON.stringify({ search })
			});

			if (!res.ok) return new Error('Failed to fetch flashcards');

			const data = await res.json();

			return data.flashcards;
		} catch (error) {
			console.error(error);

			toast.error(
				'Failed to fetch flashcards. Please try again or sign in to see more flashcards.'
			);
		}
	}

	async function goToKanji(event: MouseEvent | TouchEvent) {
		const target = event.target as HTMLButtonElement;
		const word = target.textContent?.trim();
		let callback = encodeURIComponent($page.url.pathname);
		let letter = word?.length === 1 ? word : '';

		// Check if it is a word
		if (letter === '' && word) {
			const foundFlashcards = await fetchFlashcards(word);

			if (foundFlashcards?.length === 0 || !foundFlashcards)
				return toast.error(
					'This word is not found. Find it by breaking down to kanji or please leave a feedback by clicking the 🐞 above'
				);

			const foundWord = foundFlashcards.find((flashcard: RecordModel) => {
				if (flashcard.name === word) return true;
				else return true;
			});

			if (!foundWord)
				return toast.error(
					'This word is not found. Find it by breaking down to kanji or please leave a feedback by clicking the 🐞 above'
				);

			toast.success(`Found the word: ${foundWord.name}. Redirecting to the flashcard page...`);

			$searchedWordStore = foundWord;

			return goto(`/flashcards/${foundWord?.flashcardBox}?callback=${callback}`);
		}

		// If the letter is a katakana or hiragana, redirect to the alphabets page
		if (letter && (isKatakana(letter) || isHiragana(letter))) {
			const isKatakanaLetter = isKatakana(letter);

			return toast.error('Please look for it in alphabets section.', {
				action: {
					label: isKatakanaLetter ? 'Katakana' : 'Hiragana',
					onClick: () => goto(`/alphabets/${isKatakanaLetter ? 'katakana' : 'hiragana'}`)
				}
			});
		}

		const kanjiExists = $kanjiStore.find((k) => k === letter);

		// Check if the letter is available in the kanji store
		if (!kanjiExists || !letter) {
			return toast.error(
				'This kanji is not available. Please leave a feedback by clicking the 🐞 above'
			);
		}

		// Redirect to the kanji page
		$searchKanji = letter;

		return goto('/alphabets/kanji');
	}
</script>

<section class="flex h-full flex-col justify-center gap-4 sm:gap-5">
	{#if recognizedLetters.length > 0}
		<ScrollArea class="overflow-y-visible whitespace-nowrap" orientation="horizontal">
			<div
				class="flex w-max space-x-4 pb-4"
				style={`width: ${getFlashcardWidth($innerWidthStore)}px;`}
			>
				{#each recognizedLetters as letter}
					<Button
						variant="ghost"
						class="relative flex flex-col rounded-md border p-5"
						on:click={goToKanji}
					>
						<span class="text-2xl font-bold">{letter}</span>
					</Button>
				{/each}
			</div>
		</ScrollArea>
	{:else}
		<div
			class="invisible flex w-max space-x-4 pb-4 opacity-0"
			style={`width: ${getFlashcardWidth($innerWidthStore)}px;`}
		>
			{#each ['あ'] as letter}
				<Button
					variant="ghost"
					class="relative flex flex-col rounded-md border p-5"
					on:click={goToKanji}
				>
					<span class="text-2xl font-bold">{letter}</span>
				</Button>
			{/each}
		</div>
	{/if}

	<div style="perspective: 3000px;">
		<div>
			<Canvas {canvas} />

			<button
				on:click|preventDefault={() => {
					clearCanvas(ctx, canvas);
					// CLear handwritingInstance
					handwritingInstance.erase();

					recognizedLetters = [];
				}}
				class="fixed bottom-5 left-5 z-30 block rounded-full border bg-white p-2 shadow-sm transition-all"
			>
				<CircleX />
			</button>

			<button
				on:click={findKanji}
				class="fixed bottom-5 right-5 z-30 block rounded-full border bg-white p-2 shadow-sm transition-all"
			>
				<CirclePlus />
			</button>
		</div>
	</div>
</section>