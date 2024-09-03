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
	import { Button } from '$lib/components/ui/button/';
	import * as Tooltip from '$lib/components/ui/tooltip';

	export let wordFlashcard: FlashcardType | undefined;

	let islocalBoxTypeOriginal = getLocalStorageItem('flashcardsBoxType');
	let audioSource = '';
	let audioElement: HTMLAudioElement;
	let loading = false;

	let form: SuperForm<Infer<FlashcardSchema>> = getContext('flashcardForm');

	const { form: formData, reset } = form;

	async function convertTextToSpeech() {
		loading = true;
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
		loading = false;
	}

	$: if (wordFlashcard) audioSource = '';

	$: isOriginal =
		$flashcardsBoxType &&
		$flashcardsBoxType !== 'original' &&
		islocalBoxTypeOriginal &&
		islocalBoxTypeOriginal !== 'original';

	$: createdByUser = $page.data.user?.id === wordFlashcard?.user;

	$: showEdit = $page.data.isLoggedIn && (isOriginal || $page.data.isAdmin || createdByUser);
</script>

{#if audioSource}
	<audio src={audioSource} bind:this={audioElement} />
{/if}

<div class="flex items-center justify-between gap-8 rounded-full bg-black px-4 py-2 text-white">
	<CallbackBtn />

	<Tooltip.Root>
		<Tooltip.Trigger>
			<Button
				variant="none"
				size="icon"
				class="flex items-center"
				{loading}
				disabled={loading}
				on:click={async () => {
					if (audioSource === '') await convertTextToSpeech();
					if (audioElement) audioElement.play();
				}}
			>
				<Volume2 class="size-5" />
			</Button>
		</Tooltip.Trigger>
		<Tooltip.Content>
			<p>Play audio</p>
		</Tooltip.Content>
	</Tooltip.Root>

	<Tooltip.Root>
		<Tooltip.Trigger>
			<Button
				variant="none"
				size="icon"
				class="flex items-center"
				on:click={() => ($canIdrawMultipleTimes = true)}
			>
				<GalleryHorizontalEnd class="size-5" />
			</Button>
		</Tooltip.Trigger>
		<Tooltip.Content>
			<p>Draw multiple times</p>
		</Tooltip.Content>
	</Tooltip.Root>

	{#if showEdit}
		<Tooltip.Root>
			<Tooltip.Trigger>
				<Button
					variant="none"
					size="icon"
					class="flex items-center"
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
								user: wordFlashcard?.user,
								partOfSpeech: wordFlashcard?.partOfSpeech,
							},
						});

						$currentFlashcardTypeStore = wordFlashcard?.type ?? '';
					}}
				>
					<ArrowUpCircle class="size-5" />
				</Button>
			</Tooltip.Trigger>
			<Tooltip.Content>
				<p>Edit</p>
			</Tooltip.Content>
		</Tooltip.Root>
	{/if}

	{#if !isNonJapanase($currentFlashcard)}
		<Tooltip.Root>
			<Tooltip.Trigger>
				<Button
					variant="none"
					size="icon"
					class="flex items-center"
					on:click={() => {
						$showLetterDrawing = true;
						$showProgressSlider = false;
					}}
				>
					<PenTool class="size-5" />
				</Button>
			</Tooltip.Trigger>
			<Tooltip.Content>
				<p>Draw each letter</p>
			</Tooltip.Content>
		</Tooltip.Root>
	{/if}

	<Tooltip.Root>
		<Tooltip.Trigger>
			<Button
				variant="none"
				size="icon"
				class="flex items-center"
				on:click={() => ($showCustomContent = !$showCustomContent)}
			>
				<Box class="size-5" />
			</Button>
		</Tooltip.Trigger>
		<Tooltip.Content>
			<p>Custom content</p>
		</Tooltip.Content>
	</Tooltip.Root>
</div>
