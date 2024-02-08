<script lang="ts">
	import {
		clickedEditFlashcard,
		clickedAddFlashcardCollection,
		currentFlashcardTypeStore
	} from '$lib/utils/stores';
	import { ArrowUpCircle } from 'lucide-svelte';
	import type { FlashcardType } from '$lib/utils/ambient.d.ts';

	export let form: any;

	export let currentFlashcard: FlashcardType;
</script>

<button
	class="z-40"
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
	<ArrowUpCircle class="h-5 w-5" />
</button>
