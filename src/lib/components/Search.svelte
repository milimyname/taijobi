<script lang="ts">
	import { searchedWordStore, openSearch, searchKanji, loading } from '$lib/utils/stores';
	import { onMount, tick } from 'svelte';
	import { cn, getRandomKanji } from '$lib/utils.js';
	import * as Command from '$lib/components/ui/command';
	import { page } from '$app/stores';
	import { pocketbase } from '$lib/utils/pocketbase';
	import Button from './ui/button/button.svelte';
	import { goto } from '$app/navigation';
	import { toast } from 'svelte-sonner';
	import { isRomaji } from 'wanakana';

	let search = '';
	let fetchedData: any[] = getRandomKanji();
	let value: string = fetchedData[0].id;

	// Fetch flashcards from the server
	async function fetchFlashcards() {
		if (search === '') return;
		$loading = true;

		try {
			const res = await fetch('/api/flashcard', {
				method: 'POST',
				body: JSON.stringify({ search }),
			});

			if (!res.ok) return new Error('Failed to fetch flashcards');

			const data = await res.json();

			fetchedData = data.flashcards;

			// Get paragraphs if there are any
			if (data.paragraphs && data.paragraphs.length > 0) {
				fetchedData = [
					...fetchedData,
					...data.paragraphs.map((paragraph) => ({
						id: paragraph.id,
						type: 'paragraph',
						meaning: paragraph.formatted_ai_data.meaning,
						name: paragraph.formatted_ai_data.kana,
						nameLength: paragraph.formatted_ai_data.kana.length,
					})),
				];
			}

			// Set first item to currentHoveredFlashcard
			await tick();
			currentHoveredFlashcard = fetchedData[0];
		} catch (error) {
			console.error(error);
		}

		$loading = false;
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

		// If it is a paragraph, go to the paragraph page and highlight the searched word
		if ($searchedWordStore.type && $searchedWordStore.type === 'paragraph') {
			const tabValue = isRomaji(search) ? 'details' : 'extracted';

			const baseUrl = '/paragraphs/' + $searchedWordStore.id + `?tab=${tabValue}`;
			await goto(baseUrl);
			await tick();
			window.location.hash = ':~:text=' + encodeURIComponent(search);
			return;
		}

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

	// Function to highlight matching text
	function highlightText(text: string) {
		const regex = new RegExp(`(${search})`, 'gi');
		return text.replace(regex, '<mark>$1</mark>');
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
	<Command.List class="md:h-[40rem] md:max-h-[40rem]">
		<Command.Empty
			class="flex flex-col items-center justify-center space-y-2 max-sm:h-[78dvh] md:h-[40rem]"
		>
			<p class="text-xl">No results found.</p>
			<Button href="/chat">Go to Chat</Button>
		</Command.Empty>
		{#if fetchedData && fetchedData.length > 0}
			<div class="relative grid h-full grid-cols-3">
				<Command.Group
					heading="Suggestions"
					class={cn('border-r', fetchedData.length < 4 && 'h-full max-md:h-[78dvh] md:h-[40rem]')}
				>
					{#each fetchedData as flashcard}
						<Command.Item value={flashcard.id} class="flex flex-col items-start gap-0.5">
							<h4 class="line-clamp-3 font-medium">
								{@html highlightText(flashcard.name)}
							</h4>
							<h4 class="line-clamp-3 font-medium">
								{@html highlightText(flashcard.meaning)}
							</h4>
						</Command.Item>
					{/each}
				</Command.Group>

				{#if currentHoveredFlashcard}
					<div
						class={cn(
							'sticky top-0 col-span-2 flex flex-col items-center gap-2 overflow-auto p-1 px-2 pb-14 max-md:h-[78dvh] md:h-[40rem]',
							currentHoveredFlashcard.name.length < 300 && 'justify-center',
						)}
					>
						{#if currentHoveredFlashcard.furigana}
							<h2
								class={cn(
									'text-balance text-center text-5xl leading-normal',
									currentHoveredFlashcard.name.length > 15 && 'text-xl',
								)}
							>
								{@html highlightText(currentHoveredFlashcard.furigana)}
							</h2>
						{:else}
							<h2
								class={cn(
									'text-balance text-center text-5xl leading-normal',
									currentHoveredFlashcard.name.length > 15 && 'text-xl',
								)}
							>
								{@html highlightText(currentHoveredFlashcard.name)}
							</h2>
						{/if}

						<h3>{@html highlightText(currentHoveredFlashcard.meaning)}</h3>

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
								class="fixed bottom-2 line-clamp-1 h-10 w-40 whitespace-pre break-words bg-black text-center text-white underline"
							>
								<span class="italic">
									{#if currentHoveredFlashcard?.expand}
										Collection {currentHoveredFlashcard.expand.flashcardBox.name}
									{:else}
										See it
									{/if}
								</span>
							</Button>
						{/if}
					</div>
				{/if}
			</div>
		{/if}
	</Command.List>
</Command.Dialog>
