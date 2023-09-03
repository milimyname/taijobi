<script lang="ts">
	import { onMount, afterUpdate } from 'svelte';
	import {
		clickedAddFlashcard,
		clickedEditFlashcard,
		clickedDeleteFlashcard
	} from '$lib/utils/stores';
	import { goto } from '$app/navigation';
	import { icons } from '$lib/utils/icons';
	import { page } from '$app/stores';

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
	class="flex h-full select-none flex-col items-center overflow-hidden bg-white px-3 py-5 transition-all {$clickedAddFlashcard &&
		'mt-5 rounded-t-2xl py-14'}"
>
	<nav class="z-[99] flex w-full justify-between p-5">
		<button
			on:click|preventDefault={() => {
				$page.route.id && goto($page.route.id.length < 12 ? '/' : '/flashcards');
			}}
			class="flex items-center gap-2"
		>
			{@html icons.previous}
			<span>Back</span>
		</button>
		<button
			on:click|preventDefault={() => {
				$clickedAddFlashcard = !$clickedAddFlashcard;
				$clickedEditFlashcard = false;
				$clickedDeleteFlashcard = false;
			}}
			class="transition-all hover:scale-110 active:scale-110"
		>
			{@html icons.collection}
		</button>
	</nav>

	<slot />
</main>
