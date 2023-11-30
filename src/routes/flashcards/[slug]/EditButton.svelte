<script lang="ts">
	import { icons } from '$lib/utils/icons';
	import { clickedEditFlashcard, clickedAddFlashcardCollection } from '$lib/utils/stores';

	export let form;
	export let data;
	export let currentIndex: number;
</script>

<button
	on:click|stopPropagation={() => {
		$clickedAddFlashcardCollection = true;
		$clickedEditFlashcard = true;
		// Fill out the form with the current card data
		if (data.flashcards.at(currentIndex).customFurigana)
			$form.name = data.flashcards.at(currentIndex).customFurigana;
		else $form.name = data.flashcards.at(currentIndex).name;

		$form.meaning = data.flashcards.at(currentIndex).meaning;
		$form.id = data.flashcards.at(currentIndex).id;
		$form.notes = data.flashcards.at(currentIndex).notes;
		$form.type = data.flashcards.at(currentIndex).type;
		$form.romanji = data.flashcards.at(currentIndex).romanji;
	}}
>
	{@html icons.edit}
</button>
