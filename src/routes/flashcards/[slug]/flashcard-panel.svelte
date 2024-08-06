<script lang="ts">
	import { page } from '$app/stores';
	import CallbackBtn from '$lib/components/callback-btn.svelte';
	import { isNonJapanase } from '$lib/utils';
	import type { FlashcardType } from '$lib/utils/ambient';
	import { getLocalStorageItem } from '$lib/utils/localStorage';
	import {
		showCustomContent,
		canIdrawMultipleTimes,
		showLetterDrawing,
		currentFlashcard,
		showProgressSlider,
		flashcardsBoxType,
		clickedEditFlashcard,
		clickedAddFlashcardCollection,
		currentFlashcardTypeStore,
	} from '$lib/utils/stores';
	import { GalleryHorizontalEnd, PenTool, Volume2, ArrowUpCircle, Box } from 'lucide-svelte';
	import { getContext } from 'svelte';
	import type { Infer, SuperForm } from 'sveltekit-superforms';
	import type { FlashcardSchema } from '$lib/utils/zodSchema';

	export let wordFlashcard: FlashcardType | undefined;

	let islocalBoxTypeOriginal = getLocalStorageItem('flashcardsBoxType');
	let audioSource = '';
	let audioElement: HTMLAudioElement;

	let form: SuperForm<Infer<FlashcardSchema>> = getContext('flashcardForm');

	const { form: formData, reset } = form;

	async function convertTextToSpeech() {
		try {
			const res = await fetch('/api/openai', {
				method: 'POST',
				headers: {
					'Content-Type': 'application/json',
				},
				body: JSON.stringify({ input: wordFlashcard?.name, type: 'audio' }),
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

	$: showEdit =
		$page.data.isLoggedIn &&
		(($flashcardsBoxType !== 'original' && islocalBoxTypeOriginal !== 'original') ||
			$page.data.isAdmin);
</script>

{#if audioSource}
	<audio src={audioSource} bind:this={audioElement} />
{/if}

<div class="flex items-center justify-between gap-8 rounded-full bg-black px-4 py-2 text-white">
	<CallbackBtn />

	<button
		on:click={async () => {
			if (audioSource === '') await convertTextToSpeech();
			if (audioElement) audioElement.play();
		}}
	>
		<Volume2 class="size-4" />
	</button>

	<button on:click={() => ($canIdrawMultipleTimes = true)}>
		<GalleryHorizontalEnd class="size-4" />
	</button>

	{#if showEdit}
		<button
			on:click={() => {
				$clickedAddFlashcardCollection = true;
				$clickedEditFlashcard = true;

				// Fill out the form with the current card data
				reset({
					data: {
						...$formData,
						name: wordFlashcard?.customFurigana
							? wordFlashcard?.customFurigana
							: wordFlashcard?.name,
						meaning: wordFlashcard?.meaning,
						id: wordFlashcard?.id,
						notes: wordFlashcard?.notes,
						type: wordFlashcard?.type ?? '',
						romaji: wordFlashcard?.romaji,
					},
				});

				$currentFlashcardTypeStore = wordFlashcard?.type ?? '';
			}}
		>
			<ArrowUpCircle class="size-4" />
		</button>
	{/if}

	{#if !isNonJapanase($currentFlashcard)}
		<button
			on:click={() => {
				$showLetterDrawing = true;
				$showProgressSlider = false;
			}}
		>
			<PenTool class="size-4" />
		</button>
	{/if}

	<button on:click|preventDefault={() => ($showCustomContent = !$showCustomContent)}>
		<Box class="size-4" />
	</button>
</div>
