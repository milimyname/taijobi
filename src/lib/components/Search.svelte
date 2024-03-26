<script lang="ts">
	import { searchedWordStore, openSearch } from '$lib/utils/stores';
	import { onMount } from 'svelte';
	import { getRandomKanji } from '$lib/utils.js';
	import * as Command from '$lib/components/ui/command';

	let search = '';
	let fetchedData: any[] = getRandomKanji();
	let value: string = fetchedData[0].name;

	// Fetch flashcards from the server
	async function fetchFlashcards() {
		if (search === '') return;

		try {
			const res = await fetch('/api/flashcard', {
				method: 'POST',
				body: JSON.stringify({ search })
			});

			if (!res.ok) return new Error('Failed to fetch flashcards');

			const data = await res.json();

			fetchedData = data.flashcards;
		} catch (error) {
			console.error(error);
		}
	}

	onMount(() => {
		function handleKeydown(e: KeyboardEvent) {
			if (e.key === 'k' && (e.metaKey || e.ctrlKey)) {
				e.preventDefault();
				$openSearch = !$openSearch;
			}
		}

		document.addEventListener('keydown', handleKeydown);
		return () => {
			document.removeEventListener('keydown', handleKeydown);
		};
	});

	$: if (search === '') fetchedData = getRandomKanji();

	$: if (search !== '') setTimeout(async () => await fetchFlashcards(), 100);

	$: if (search !== '' && fetchedData.length === 0) value = '';

	$: currentHoveredFlashcard = fetchedData?.find((flashcard) => flashcard.name === value);

	$: fetchedData.length === 1 && (value = fetchedData[0].name);
</script>

<Command.Dialog bind:open={$openSearch} bind:value shouldFilter={false}>
	<Command.Input
		bind:value={search}
		placeholder="Find a japanese letter or flashcard by meaning or name"
	/>
	<Command.List>
		<Command.Empty>No results found.</Command.Empty>
		<div class="relative grid grid-cols-3">
			{#if fetchedData.length > 0}
				<Command.Group heading="Suggestions" class="border-r">
					{#each fetchedData as flashcard}
						<Command.Item value={flashcard.name} class="flex flex-col items-start gap-0.5">
							<h4 class="font-medium">{flashcard.name}</h4>
							<h4>{flashcard.meaning}</h4>
						</Command.Item>
					{/each}
				</Command.Group>
			{/if}

			{#if currentHoveredFlashcard}
				<div
					class="sticky top-0 col-span-2 flex h-[60dvh] flex-col items-center justify-center gap-10 px-2 md:h-72"
				>
					{#if currentHoveredFlashcard.furigana}
						<h2 class="text-center text-4xl">
							{@html currentHoveredFlashcard.furigana}
						</h2>
					{:else}
						<h2 class="text-4xl font-bold">{currentHoveredFlashcard.name}</h2>
					{/if}

					<h3>{currentHoveredFlashcard.meaning}</h3>
					<a
						href={`/search/${value}`}
						on:click={() => {
							$openSearch = false;
							$searchedWordStore = currentHoveredFlashcard;
						}}
						class="underline"
					>
						See more
					</a>
				</div>
			{/if}
		</div>
	</Command.List>
</Command.Dialog>
