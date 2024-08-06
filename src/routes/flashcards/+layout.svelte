<script lang="ts">
	import {
		clickedAddFlashcardCollection,
		clickedAddFlahcardBox,
		clickedEditFlashcard,
		flashcardsBoxType,
		currentIndexStore,
		showLetterDrawing,
		selectedQuizItems,
		canIdrawMultipleTimes,
	} from '$lib/utils/stores';
	import { page } from '$app/stores';
	import { ArrowLeft, FolderPlus } from 'lucide-svelte';
	import { getLocalStorageItem } from '$lib/utils/localStorage.js';
	import { goto } from '$app/navigation';
	import { removeAllItemsWithPrefixFromLocalStorage } from '$lib/utils';
	import { Button } from '$lib/components/ui/button';

	export let data;

	function handleAddFlashcardCollection() {
		$clickedAddFlashcardCollection = true;
		$clickedAddFlahcardBox = false;
		$clickedEditFlashcard = false;
	}

	$: $flashcardsBoxType = getLocalStorageItem('flashcardsBoxType') as string;
</script>

<svelte:head>
	<title>Flashcards</title>
	<meta name="Flashcards" content="Flashcards" />
</svelte:head>

<main class="flex h-dvh flex-col items-center bg-white transition-all">
	<nav class="flex w-full items-center justify-between p-5 sm:py-5">
		<Button
			size="icon"
			variant="none"
			class="go-back-btn group flex items-center gap-2"
			on:click={() => {
				// Remove the flashcards box type from the local storage
				removeAllItemsWithPrefixFromLocalStorage(`${$page.params.slug}`);

				// Reset the store values
				if ($canIdrawMultipleTimes) return ($canIdrawMultipleTimes = false);

				$currentIndexStore = 0;
				$showLetterDrawing = false;
				$selectedQuizItems = [];
				$canIdrawMultipleTimes = false;

				// Clear the local storage for the flashcards box type
				localStorage.removeItem('flashcardsBoxType');

				goto($page.route.id && $page.route.id.length < 12 ? '/' : '/flashcards');
			}}
			data-sveltekit-preload-data
		>
			<ArrowLeft
				class="size-4 transition-transform  group-hover:-translate-x-2  group-active:-translate-x-2 "
			/>
		</Button>

		{#if data.isLoggedIn}
			{#if data.isAdmin}
				<button
					on:click={handleAddFlashcardCollection}
					class="add-btn transition-all hover:scale-110 active:scale-110"
				>
					<FolderPlus />
				</button>
			{:else if $flashcardsBoxType && $flashcardsBoxType !== 'original'}
				<button
					on:click={handleAddFlashcardCollection}
					class="add-btn transition-all hover:scale-110 active:scale-110"
				>
					<FolderPlus />
				</button>
			{:else if $page.route.id && $page.route.id.endsWith('/flashcards')}
				<button
					on:click={handleAddFlashcardCollection}
					class="add-btn transition-all hover:scale-110 active:scale-110"
				>
					<FolderPlus />
				</button>
			{/if}
		{/if}
	</nav>

	<slot />
</main>
