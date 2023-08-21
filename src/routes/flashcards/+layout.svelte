<script lang="ts">
	import { onMount, afterUpdate } from 'svelte';
	import { clickedAddFlashcard } from '$lib/utils/stores';

	onMount(() => {
		document.body.style.backgroundColor = $clickedAddFlashcard ? 'rgb(0,0,0)' : 'rgb(255,255,255)';
	});

	afterUpdate(() => {
		document.body.style.backgroundColor = $clickedAddFlashcard ? 'rgb(0,0,0)' : 'rgb(255,255,255)';
	});
</script>

<svelte:head>
	<title>Flashcards</title>
	<meta name="description" content="Flashcards" />
	<meta name="theme-color" content="rgb(0,0,0)" />
</svelte:head>

<main
	class="flex h-full select-none flex-col items-center bg-white px-3 py-5 transition-all {$clickedAddFlashcard &&
		'mt-5 rounded-t-2xl py-12'}"
>
	<slot />
</main>
