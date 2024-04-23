<script lang="ts">
	import {
		clickedEditFlashcard,
		clickedAddFlashcardCollection,
		currentFlashcardTypeStore
	} from '$lib/utils/stores';
	import { ArrowUpCircle, Dices } from 'lucide-svelte';
	import type { FlashcardType } from '$lib/utils/ambient.d.ts';
	import { onMount } from 'svelte';
	import { page } from '$app/stores';
	import { goto } from '$app/navigation';

	export let form: any;
	export let currentFlashcard: FlashcardType;
	let callback: string;

	onMount(() => {
		const urlParams = new URLSearchParams($page.url.search);
		callback = decodeURIComponent(urlParams.get('callback') || '/');
	});
</script>

<button
	class="mr-2 flex items-center gap-2 rounded-full border px-4 py-2"
	on:click={() => goto(callback)}
>
	<Dices class="size-5" />
	<span>Return to Quiz</span>
</button>

<button
	class="rounded-full bg-black px-4 py-2 text-white"
	on:click={() => {
		$clickedAddFlashcardCollection = true;
		$clickedEditFlashcard = true;

		// Fill out the form with the current card data
		$form = {
			...form.data,
			name: currentFlashcard.customFurigana
				? currentFlashcard.customFurigana
				: currentFlashcard.name,
			meaning: currentFlashcard.meaning,
			id: currentFlashcard.id,
			notes: currentFlashcard.notes,
			type: currentFlashcard.type,
			romanji: currentFlashcard.romanji
		};

		$currentFlashcardTypeStore = currentFlashcard.type ?? '';
	}}
>
	<ArrowUpCircle class="size-5" />
</button>
