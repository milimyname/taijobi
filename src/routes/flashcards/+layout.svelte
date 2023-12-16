<script lang="ts">
	import { onMount, afterUpdate } from 'svelte';
	import {
		clickedAddFlashcardCollection,
		clickedAddFlahcardBox,
		clickedEditFlashcard,
		showCollections,
		clickedQuizForm,
		flashcardsBoxType,
		currentFlashcard
	} from '$lib/utils/stores';
	import { page } from '$app/stores';
	import { getLocalStorageItem } from '$lib/utils/localStorage';
	import { ArrowLeft, FolderPlus } from 'lucide-svelte';

	onMount(() => {
		if ($clickedAddFlashcardCollection) document.body.style.backgroundColor = 'rgb(0,0,0)';
		else if ($clickedQuizForm) document.body.style.backgroundColor = 'rgb(0,0,0)';
		else document.body.style.backgroundColor = 'rgb(255,255,255)';
	});

	afterUpdate(() => {
		if ($clickedAddFlashcardCollection) document.body.style.backgroundColor = 'rgb(0,0,0)';
		else if ($clickedQuizForm) document.body.style.backgroundColor = 'rgb(0,0,0)';
		else document.body.style.backgroundColor = 'rgb(255,255,255)';
	});

	let islocalBoxTypeOriginal = getLocalStorageItem('flashcardsBoxType') !== 'original';
</script>

<svelte:head>
	<title>Flashcards</title>
	<meta name="description" content="Flashcards" />
	<!-- <meta name="theme-color" content="rgb(0,0,0)" /> -->
</svelte:head>

{#if $showCollections || $clickedAddFlahcardBox || $clickedAddFlashcardCollection}
	<div class="fixed top-0 z-[100] h-[100dvh] w-screen bg-black/50 backdrop-blur-md" />
{/if}

<main
	class="flex h-[100dvh] select-none flex-col items-center overflow-hidden bg-white p-2 transition-all sm:px-3 sm:py-5 {$clickedAddFlashcardCollection &&
		'mt-5 rounded-t-2xl py-14'} {$clickedQuizForm && 'mt-5 rounded-t-2xl py-14'}"
>
	<nav class="flex w-full justify-between px-2 py-3 xm:p-5">
		<a
			href={$page.route.id && $page.route.id.length < 12 ? '/' : '/flashcards'}
			class="go-back-btn group flex items-center gap-2"
			on:click={() => ($currentFlashcard = '')}
			data-sveltekit-preload-data
		>
			<ArrowLeft
				class="h-4 w-4 transition-transform  group-hover:-translate-x-2  group-active:-translate-x-2 "
			/>
			<span>Back</span>
		</a>

		{#if $page.route.id && $page.route.id.length < 12}
			<button
				on:click={() => {
					$clickedAddFlahcardBox = false;
					$clickedAddFlashcardCollection = true;
					$clickedEditFlashcard = false;
				}}
				class="add-btn transition-all hover:scale-110 active:scale-110"
			>
				<FolderPlus />
			</button>
		{:else if ($flashcardsBoxType !== 'original' && islocalBoxTypeOriginal) || $page.data.isAdmin}
			<button
				on:click={() => {
					$clickedAddFlahcardBox = false;
					$clickedAddFlashcardCollection = true;
					$clickedEditFlashcard = false;
				}}
				class="add-btn transition-all hover:scale-110 active:scale-110"
			>
				<FolderPlus />
			</button>
		{/if}
	</nav>

	<slot />
</main>
