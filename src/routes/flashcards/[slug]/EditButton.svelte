<script lang="ts">
	import { clickedEditFlashcard, clickedAddFlashcardCollection } from '$lib/utils/stores';
	import { ArrowUpCircle } from 'lucide-svelte';
	import type { FlashcardType } from '$lib/utils/ambient.d.ts';

	export let form;
	export let flashcards: FlashcardType[];
	export let currentIndex: number;
</script>

<button
	class="z-40"
	on:click|stopPropagation={() => {
		$clickedAddFlashcardCollection = true;
		$clickedEditFlashcard = true;
		const fetchedFlashcard = flashcards[currentIndex];

		// Fill out the form with the current card data
		if (fetchedFlashcard.customFurigana) $form.name = fetchedFlashcard.customFurigana;
		else $form.name = fetchedFlashcard.name;

		$form.meaning = fetchedFlashcard.meaning;
		$form.id = fetchedFlashcard.id;
		$form.notes = fetchedFlashcard.notes;
		$form.type = fetchedFlashcard.type;
		$form.romanji = fetchedFlashcard.romanji;
	}}
>
	<ArrowUpCircle class="h-5 w-5" />
</button>
