<script lang="ts">
	import { searchedWordStore, openSearch, searchKanji } from '$lib/utils/stores';
	import { onMount } from 'svelte';
	import { cn, getRandomKanji } from '$lib/utils.js';
	import * as Command from '$lib/components/ui/command';
	import { page } from '$app/stores';
	import { pocketbase } from '$lib/utils/pocketbase';
	import Button from './ui/button/button.svelte';
	import { goto } from '$app/navigation';
	import { toast } from 'svelte-sonner';

	let search = '';
	let fetchedData: any[] = getRandomKanji();
	let value: string = fetchedData[0].id;

	// Fetch flashcards from the server
	async function fetchFlashcards() {
		if (search === '') return;

		// if (fetchedData.length === 0) return;

		try {
			const res = await fetch('/api/flashcard', {
				method: 'POST',
				body: JSON.stringify({ search }),
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

	async function handleClick() {
		$openSearch = false;
		$searchedWordStore = currentHoveredFlashcard;

		// If it is a kanji, go to the kanji page
		if (!$searchedWordStore.type) {
			if (!$searchedWordStore.type) $searchKanji = $searchedWordStore?.name;
			goto('/alphabets/kanji');
			return;
		}

		try {
			const newSearch = await pocketbase.collection('searches').create({
				flashcard: currentHoveredFlashcard.id,
				user: $page.data.user.id,
				searchQuery: search,
			});

			if (!newSearch) throw new Error('Failed to create search');

			pocketbase.collection('flashcard').update(currentHoveredFlashcard.id, {
				'searches+': newSearch.id,
			});

			goto(`/search/${newSearch.id}`);
		} catch (error) {
			console.error(error);
		}
	}

	$: if (search === '') fetchedData = getRandomKanji();

	$: if (search) setTimeout(() => fetchFlashcards(), 100);

	$: if (search !== '' && fetchedData && fetchedData.length === 0) value = '';

	$: currentHoveredFlashcard = fetchedData?.find((flashcard) => flashcard.id === value);

	$: fetchedData && fetchedData.length === 1 && (value = fetchedData[0].id);
</script>

<Command.Dialog bind:open={$openSearch} bind:value shouldFilter={false}>
	<Command.Input
		bind:value={search}
		disabled={!$page.data.isLoggedIn}
		placeholder={!$page.data.isLoggedIn
			? 'You have reached the maximum number of suggestions. Please sign in to see more.'
			: 'Search for a word...'}
	/>
	<Command.List>
		<Command.Empty class="space-y-2 max-sm:h-[78dvh]">
			<p class="h-full text-xl">No results found.</p>

			<div class="sticky bottom-4 px-4">
				<Button variant="link" href="/chat" class="w-full">Go to Chat</Button>
			</div>
		</Command.Empty>
		{#if fetchedData && fetchedData.length > 0}
			<div class="relative grid grid-cols-3">
				<Command.Group
					heading="Suggestions"
					class={cn('border-r', fetchedData.length < 4 && 'h-full max-md:h-[78dvh]')}
				>
					{#each fetchedData as flashcard}
						<Command.Item value={flashcard.id} class="flex flex-col items-start gap-0.5">
							<h4 class="font-medium">{flashcard.name}</h4>
							<h4>{flashcard.meaning}</h4>
						</Command.Item>
					{/each}
				</Command.Group>

				{#if currentHoveredFlashcard}
					<div
						class="sticky top-0 col-span-2 flex h-fit flex-col items-center justify-center gap-10 overflow-hidden px-2 max-md:h-[78dvh] md:h-72"
					>
						{#if currentHoveredFlashcard.furigana}
							<h2 class="text-center text-4xl">
								{@html currentHoveredFlashcard.furigana}
							</h2>
						{:else}
							<h2 class="text-4xl font-bold">{currentHoveredFlashcard.name}</h2>
						{/if}

						<h3>{currentHoveredFlashcard.meaning}</h3>

						{#if currentHoveredFlashcard?.searches && currentHoveredFlashcard?.flashcardBox === '' && currentHoveredFlashcard?.searches[0]}
							<Button
								variant="link"
								href={`/search/${currentHoveredFlashcard?.searches[0]}`}
								class="text-center underline"
							>
								Search it
							</Button>
						{:else}
							<Button
								variant="none"
								on:click={() => {
									toast.promise(handleClick, {
										loading: 'Searching...',
										success: 'Found it!',
										error: 'Failed to search',
									});
								}}
								class="text-center underline"
							>
								{#if currentHoveredFlashcard?.expand}
									<span class="italic">
										Collection {currentHoveredFlashcard.expand.flashcardBox.name}
									</span>
								{:else}
									<span class="italic">See it</span>
								{/if}
							</Button>
						{/if}
					</div>
				{/if}
			</div>
		{/if}
	</Command.List>
</Command.Dialog>
