<script lang="ts">
	import {
		innerHeightStore,
		innerWidthStore,
		searchedWordStore,
		searchKanji,
		openHistory,
	} from '$lib/utils/stores';
	import { getFlashcardHeight, getFlashcardWidth } from '$lib/utils';
	import Button from '$lib/components/ui/button/button.svelte';
	import { History } from 'lucide-svelte';
	import SearchDrawerDialog from './search-drawer-dialog.svelte';
	import { goto } from '$app/navigation';

	export let data;

	$: $searchedWordStore = data.currentSearch?.expand?.flashcard;

	function showHistory() {
		$openHistory = true;
	}
</script>

<SearchDrawerDialog searches={data.searches} />

<section class="flex h-full w-full flex-col items-center justify-center gap-5 lg:flex-col-reverse">
	<div style="perspective: 3000px; position: relative;">
		<div
			style={`height: ${getFlashcardHeight($innerWidthStore, $innerHeightStore)}px;
				width: ${getFlashcardWidth($innerWidthStore)}px `}
			class="relative z-10 flex cursor-pointer items-center justify-center rounded-xl border shadow-sm bg-dotted-spacing-8 bg-dotted-gray-200"
		>
			{#if $searchedWordStore?.type === 'kanji'}
				<span class="text-9xl sm:text-[14rem]">
					{$searchedWordStore?.name}
				</span>
			{:else if $searchedWordStore?.type === 'phrase'}
				<p class="text-balance px-10 text-center text-5xl leading-normal tracking-widest">
					{@html $searchedWordStore?.name}
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

	<div class="flex gap-4">
		<Button on:click={showHistory} disabled={data.searches.length === 0}>
			<History class="size-5 color-current mr-2" />
			<span>See History</span>
		</Button>
		<Button
			variant="outline"
			on:click={() => {
				if (!$searchedWordStore.type) $searchKanji = $searchedWordStore?.name;

				goto(`/flashcards/${$searchedWordStore?.flashcardBox}`);
			}}
		>
			Go to Flashcard
		</Button>
	</div>
</section>
