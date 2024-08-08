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
	import { ArrowLeft, Settings } from 'lucide-svelte';
	import { getLocalStorageItem } from '$lib/utils/localStorage.js';
	import { goto } from '$app/navigation';
	import { removeAllItemsWithPrefixFromLocalStorage } from '$lib/utils';
	import { Button } from '$lib/components/ui/button';
	import * as DropdownMenu from '$lib/components/ui/dropdown-menu';

	export let data;

	function handleAddFlashcardCollection() {
		$clickedAddFlashcardCollection = true;
		$clickedAddFlahcardBox = false;
		$clickedEditFlashcard = false;
	}

	$: $flashcardsBoxType = getLocalStorageItem('flashcardsBoxType') as string;

	$: showSettings =
		data.isLoggedIn &&
		(data.isAdmin ||
			($flashcardsBoxType && $flashcardsBoxType !== 'original') ||
			($page.route.id && $page.route.id.endsWith('/flashcards')));
</script>

<svelte:head>
	<title>Flashcards</title>
	<meta name="Flashcards" content="Flashcards" />
</svelte:head>

<main class="flex h-dvh w-screen flex-col items-center overflow-hidden bg-white">
	<nav class="flex w-full items-center justify-between p-5">
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

		{#if showSettings}
			<DropdownMenu.Root>
				<DropdownMenu.Trigger>
					<Settings class="add-btn size-5" />
				</DropdownMenu.Trigger>

				<DropdownMenu.Content class="add-btn">
					<DropdownMenu.Item disabled>Box Info</DropdownMenu.Item>
					<DropdownMenu.Item on:click={handleAddFlashcardCollection}>New</DropdownMenu.Item>
				</DropdownMenu.Content>
			</DropdownMenu.Root>
		{/if}
	</nav>

	<slot />
</main>
