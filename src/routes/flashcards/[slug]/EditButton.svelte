<script lang="ts">
	import { clickedEditFlashcard, clickedAddFlashcardCollection } from '$lib/utils/stores';
	import { ArrowUpCircle } from 'lucide-svelte';
	import type { FlashcardType } from '$lib/utils/ambient.d.ts';
	import type { SuperValidated } from 'sveltekit-superforms';
	import { type FlashcardSchema } from '$lib/utils/zodSchema';

	export let form: SuperValidated<FlashcardSchema>;

	export let currentFlashcard: FlashcardType;
</script>

<button
	class="z-40"
	on:click={() => {
		$clickedAddFlashcardCollection = true;
		$clickedEditFlashcard = true;

		// Fill out the form with the current card data
		form.data = {
			...form.data,
			name: currentFlashcard.customFurigana
				? currentFlashcard.customFurigana
				: currentFlashcard.name,
			meaning: currentFlashcard.meaning,
			id: currentFlashcard.id,
			notes: currentFlashcard.notes,
			type: currentFlashcard.type ?? '',
			romanji: currentFlashcard.romanji
		};
	}}
>
	<ArrowUpCircle class="h-5 w-5" />
</button>
