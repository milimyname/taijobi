<script lang="ts">
	import {
		clickedEditFlashcard,
		clickedAddFlashcardCollection,
		currentFlashcardTypeStore,
	} from '$lib/utils/stores';
	import { ArrowUpCircle } from 'lucide-svelte';
	import type { FlashcardType } from '$lib/utils/ambient.d.ts';
	import { getContext } from 'svelte';
	import type { Infer, SuperForm } from 'sveltekit-superforms';
	import type { FlashcardSchema } from '$lib/utils/zodSchema';

	export let currentFlashcard: FlashcardType;

	let form: SuperForm<Infer<FlashcardSchema>> = getContext('flashcardForm');

	const { form: formData, reset } = form;
</script>

<button
	class="rounded-full bg-black px-4 py-2 text-white"
	on:click={() => {
		$clickedAddFlashcardCollection = true;
		$clickedEditFlashcard = true;

		// Fill out the form with the current card data
		reset({
			data: {
				...$formData,
				name: currentFlashcard.customFurigana
					? currentFlashcard.customFurigana
					: currentFlashcard.name,
				meaning: currentFlashcard.meaning,
				id: currentFlashcard.id,
				notes: currentFlashcard.notes,
				type: currentFlashcard.type ?? '',
				romanji: currentFlashcard.romanji,
			},
		});

		$currentFlashcardTypeStore = currentFlashcard.type ?? '';
	}}
>
	<ArrowUpCircle class="size-5" />
</button>
