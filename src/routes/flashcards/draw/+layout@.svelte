<script lang="ts">
	import { page } from '$app/stores';
	import {
		clickedAddFlashcardCollection,
		clickedQuizForm,
		innerHeightStore,
		innerWidthStore
	} from '$lib/utils/stores';
	import { ArrowLeft } from 'lucide-svelte';
	import DrawingNav from '$lib/components/DrawingNav.svelte';
</script>

<svelte:head>
	<title>Flashcards Draw</title>
	<meta name="description" content="Flashcards Draw" />
</svelte:head>

<svelte:window bind:innerWidth={$innerWidthStore} bind:innerHeight={$innerHeightStore} />

<main
	class="flex h-[100dvh] select-none flex-col items-center overflow-hidden bg-white p-2 transition-all sm:px-3 sm:py-5 {$clickedAddFlashcardCollection &&
		'mt-5 rounded-t-2xl py-14'} {$clickedQuizForm && 'mt-5 rounded-t-2xl py-14'}"
>
	<nav class="flex w-full justify-between px-2 py-3 xm:p-5">
		<a
			href={'/flashcards/' + $page.url.pathname.split('-').at(1)}
			class="go-back-btn group flex items-center gap-2"
			on:click={() => localStorage.removeItem('currentFlashcard')}
			data-sveltekit-preload-data
		>
			<ArrowLeft
				class="h-4 w-4 transition-transform  group-hover:-translate-x-2  group-active:-translate-x-2 "
			/>
			<span>Back</span>
		</a>
	</nav>

	<slot />

	<DrawingNav />
</main>
