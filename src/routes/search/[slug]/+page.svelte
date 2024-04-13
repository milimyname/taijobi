<script lang="ts">
	import {
		innerHeightStore,
		innerWidthStore,
		searchedWordStore,
		searchKanji
	} from '$lib/utils/stores';
	import { getFlashcardHeight, getFlashcardWidth } from '$lib/utils';
	import Button from '$lib/components/ui/button/button.svelte';
</script>

<section class="flex h-full w-full flex-col items-center justify-center gap-5 lg:flex-col-reverse">
	<div style="perspective: 3000px; position: relative;">
		<div
			style={`height: ${getFlashcardHeight($innerWidthStore, $innerHeightStore)}px;
				width: ${getFlashcardWidth($innerWidthStore)}px `}
			class="relative z-10 flex cursor-pointer items-center justify-center rounded-xl border shadow-sm bg-dotted-spacing-8 bg-dotted-gray-200"
		>
			{#if $searchedWordStore?.type === 'kanji'}
				<span class="text-9xl sm:text-[14rem]">
					{$searchedWordStore.name}
				</span>
			{:else if $searchedWordStore?.type === 'phrase'}
				<p class="text-balance px-10 text-center text-5xl leading-normal tracking-widest">
					{@html $searchedWordStore.name}
				</p>
			{:else if $searchedWordStore?.furigana}
				<p class="vertical text-balance text-5xl leading-normal tracking-widest">
					{@html $searchedWordStore?.furigana}
				</p>
			{:else}
				<p class="text-balance text-5xl leading-normal tracking-widest">
					{$searchedWordStore.name}
				</p>
			{/if}
		</div>
	</div>

	<Button
		variant="outline"
		href={!$searchedWordStore.type
			? '/alphabets/kanji'
			: `/flashcards/${$searchedWordStore?.flashcardBox}`}
		on:click={() => {
			if (!$searchedWordStore.type) $searchKanji = $searchedWordStore.name;
		}}
	>
		Go to Flashcard
	</Button>
</section>
