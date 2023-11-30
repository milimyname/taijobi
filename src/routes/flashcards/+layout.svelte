<script lang="ts">
	import { onMount, afterUpdate } from 'svelte';
	import {
		clickedAddFlashcardCollection,
		clickedEditFlashcard,
		clickedQuizForm
	} from '$lib/utils/stores';
	import { goto } from '$app/navigation';
	import { icons } from '$lib/utils/icons';
	import { page } from '$app/stores';
	import { browser } from '$app/environment';

	let isConstantFlashcard: string;

	onMount(() => {
		if ($clickedAddFlashcardCollection) document.body.style.backgroundColor = 'rgb(0,0,0)';
		else if ($clickedQuizForm) document.body.style.backgroundColor = 'rgb(0,0,0)';
		else document.body.style.backgroundColor = 'rgb(255,255,255)';

		isConstantFlashcard = localStorage.getItem('isConstantFlashcard') as string;
	});

	afterUpdate(() => {
		if ($clickedAddFlashcardCollection) document.body.style.backgroundColor = 'rgb(0,0,0)';
		else if ($clickedQuizForm) document.body.style.backgroundColor = 'rgb(0,0,0)';
		else document.body.style.backgroundColor = 'rgb(255,255,255)';
	});

	$: if (browser) {
		// Update isConstantFlashcard value
		if (isConstantFlashcard || $page.data.isAdmin)
			isConstantFlashcard = localStorage.getItem('isConstantFlashcard') as string;
	}
</script>

<svelte:head>
	<title>Flashcards</title>
	<meta name="description" content="Flashcards" />
	<meta name="theme-color" content="rgb(0,0,0)" />
</svelte:head>

<main
	class="flex h-[100dvh] select-none flex-col items-center overflow-hidden bg-white px-3 py-5 transition-all {$clickedAddFlashcardCollection &&
		'mt-5 rounded-t-2xl py-14'} {$clickedQuizForm && 'mt-5 rounded-t-2xl py-14'}"
>
	<nav class="flex w-full justify-between p-5">
		<button
			on:click={() => {
				$page.route.id && goto($page.route.id.length < 12 ? '/' : '/flashcards');
				localStorage.setItem('isConstantFlashcard', 'false');
			}}
			class="go-back-btn flex items-center gap-2"
		>
			{@html icons.previous}
			<span>Back</span>
		</button>
		{#if $page.data.isAdmin || (!$page.data.isAdmin && isConstantFlashcard === 'false')}
			<button
				on:click={() => {
					$clickedAddFlashcardCollection = !$clickedAddFlashcardCollection;
					$clickedEditFlashcard = false;
				}}
				class="add-btn transition-all hover:scale-110 active:scale-110"
			>
				{@html icons.collection}
			</button>
		{/if}
	</nav>

	<slot />
</main>
