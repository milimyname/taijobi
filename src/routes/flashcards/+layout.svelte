<script lang="ts">
	import {
		clickedAddFlashcardCollection,
		clickedAddFlahcardBox,
		clickedEditFlashcard,
		flashcardsBoxType,
		currentIndexStore,
		showLetterDrawing,
		selectedQuizItems
	} from '$lib/utils/stores';
	import { page } from '$app/stores';
	import { ArrowLeft, FolderPlus } from 'lucide-svelte';
	import { getLocalStorageItem } from '$lib/utils/localStorage.js';

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
	<meta name="description" content="Flashcards" />
</svelte:head>

<main
	class="flex h-[100dvh] select-none flex-col items-center overflow-hidden bg-white p-2 transition-all sm:px-3 sm:py-5"
>
	<nav class="flex w-full justify-between px-2 py-3 xm:p-5">
		<a
			href={$page.route.id && $page.route.id.length < 12 ? '/' : '/flashcards'}
			class="go-back-btn group flex items-center gap-2"
			on:click={() => {
				$currentIndexStore = 0;
				$showLetterDrawing = false;
				$selectedQuizItems = [];

				// Clear the local storage for the flashcards box type
				localStorage.removeItem('flashcardsBoxType');
			}}
			data-sveltekit-preload-data
		>
			<ArrowLeft
				class="size-4 transition-transform  group-hover:-translate-x-2  group-active:-translate-x-2 "
			/>
			<span>Back</span>
		</a>

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
