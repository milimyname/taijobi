<script lang="ts">
	import {
		selectQuizItemsForm,
		clickedKanjiForm,
		selectedQuizItems,
		swapFlashcards,
	} from '$lib/utils/stores';
	import { kanji } from '$lib/static/kanji';
	import { page } from '$app/stores';
	import { pocketbase } from '$lib/utils/pocketbase';
	import { ScrollArea } from '$lib/components/ui/scroll-area/index';
	import { cn } from '$lib/utils';

	export let flashcardBox: string;

	let flashcards: {
		name: string;
		meaning: string;
		id: string;
	}[] = [];

	async function getFlashcards() {
		flashcards = await pocketbase.collection('flashcard').getFullList({
			filter: `flashcardBox = "${flashcardBox}"`,
			fields: 'name,meaning,id',
		});

		// Remove same flashcards from the list
		flashcards = flashcards.filter(
			(flashcard, i, self) => i === self.findIndex((t) => t.name === flashcard.name),
		);

		// Remove empty name flashcards
		flashcards = flashcards.filter((flashcard) => flashcard.name !== '');
	}

	$: if (($selectQuizItemsForm || $swapFlashcards) && !$page.url.pathname.includes('kanji'))
		getFlashcards();
</script>

<ScrollArea class="h-[32rem] w-full">
	<div class="select-quiz-data swap-items mb-auto px-5">
		{#if $clickedKanjiForm && $page.url.pathname.includes('kanji')}
			<ul class="grid grid-cols-2 gap-3 px-5 xm:grid-cols-4 sm:grid-cols-8">
				{#each Object.keys(kanji) as letter, i}
					<li class="flex flex-col justify-between">
						<button
							class="{$selectedQuizItems.includes(letter)
								? 'bg-black text-white hover:bg-gray-700'
								: 'border-2 border-black bg-white text-black hover:bg-gray-200'}
                         relative rounded-md px-4 py-2 font-medium shadow-lg transition duration-200 visited:-translate-x-4 active:translate-y-1 active:shadow-sm"
							on:click|preventDefault={() => {
								// Remove the letter if it's already selected
								if ($selectedQuizItems.includes(letter)) {
									$selectedQuizItems = $selectedQuizItems.filter((item) => item !== letter);
									return;
								}

								$selectedQuizItems = [...$selectedQuizItems, letter];
							}}
						>
							<span class="absolute left-1 top-0 text-[10px]">{i + 1}</span>
							<span>{letter}</span>
						</button>
					</li>
				{/each}
			</ul>
		{:else}
			<ul class="mb-auto grid grid-cols-2 gap-3 xm:grid-cols-4 md:grid-cols-4">
				{#each flashcards as flashcard, i}
					{@const formattedItem = $swapFlashcards
						? flashcard.id + '=' + flashcard.meaning
						: '---' + flashcard.name + '=' + flashcard.meaning}
					<li>
						<button
							class={cn(
								'relative size-full rounded-md border-2 border-black bg-white px-4 py-2 font-medium text-black shadow-lg transition duration-200 visited:-translate-x-4 hover:bg-gray-200 active:translate-y-1 active:shadow-sm',
								$selectedQuizItems.includes(formattedItem) &&
									'bg-black text-white hover:bg-gray-700',
							)}
							on:click|preventDefault={() => {
								// Remove the letter if it's already selected
								if ($selectedQuizItems.includes(formattedItem)) {
									$selectedQuizItems = $selectedQuizItems.filter((item) => item !== formattedItem);
									return;
								}

								$selectedQuizItems = [...$selectedQuizItems, formattedItem];
							}}
						>
							<span class="absolute left-1 top-0 text-[10px]">{i + 1}</span>
							<span>{flashcard.name}</span>
						</button>
					</li>
				{/each}
			</ul>
		{/if}
	</div>
</ScrollArea>

<slot />
