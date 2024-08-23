<script lang="ts">
	import {
		innerHeightStore,
		innerWidthStore,
		searchedWordStore,
		nestedSearchDrawerOpen,
		openHistory,
		selectedSearchFlashcards,
	} from '$lib/utils/stores';
	import { cn, getFlashcardHeight, getFlashcardWidth } from '$lib/utils';
	import Button from '$lib/components/ui/button/button.svelte';
	import { History } from 'lucide-svelte';
	import { goto } from '$app/navigation';
	import { superForm } from 'sveltekit-superforms';
	import { searchCollectionSchema } from '$lib/utils/zodSchema';
	import { zodClient } from 'sveltekit-superforms/adapters';
	import { setContext } from 'svelte';
	import { toast } from 'svelte-sonner';
	import CallBackButton from '$lib/components/callback-btn.svelte';
	import { slide } from 'svelte/transition';
	import { quintOut } from 'svelte/easing';
	import SearchDrawerDialog from '$lib/components/drawer-dialogs/search-drawer-dialog.svelte';
	import { pocketbase } from '$lib/utils/pocketbase';

	export let data;

	let showTranslation = false;

	function showHistory() {
		$openHistory = true;
	}

	// Search for Flashcard collection form:
	const superSearchForm = superForm(data.form, {
		dataType: 'json',
		validators: zodClient(searchCollectionSchema),
		onUpdated: ({ form }) => {
			// Keep the form open if there is an error
			if (Object.keys(form.errors).length !== 0) return ($nestedSearchDrawerOpen = true);

			// Close the form if there is no error
			$nestedSearchDrawerOpen = false;
			$selectedSearchFlashcards = [];
			// Set it to the current flashcard collection
			localStorage.setItem('currentFlashcardCollectionId', form.data.collectionId);
			toast('Flashcard box created successfully', {
				action: {
					label: 'See it now',
					onClick: () => {
						goto(`/flashcards/${form.data.boxId}`);
					},
				},
			});
		},
	});

	// Set Contexts
	setContext('flashcardCollections', data.flashcardCollections);
	setContext('flashcardCollectionForm', superSearchForm);
	setContext('searchedFlashcardsIds', data.flashcardsIds);
	setContext(
		'searchesIds',
		data.searches.map((s) => s.id),
	);

	$: $searchedWordStore = data.currentSearch?.expand?.flashcard;
</script>

<SearchDrawerDialog searches={data.searches} />

<section class="flex h-full w-full flex-col items-center justify-center gap-5 lg:flex-col-reverse">
	<div
		style={`height: ${getFlashcardHeight($innerWidthStore, $innerHeightStore)}px;
				width: ${getFlashcardWidth($innerWidthStore)}px `}
		class="relative z-10 flex flex-col items-center justify-center rounded-xl border shadow-sm bg-dotted-spacing-8 bg-dotted-gray-200"
	>
		{#if $searchedWordStore?.furigana}
			<div class="relative">
				<p
					class={cn(
						'text-balance text-center text-4xl',
						$searchedWordStore.type === 'phrase' && 'px-10 text-4xl ![writing-mode:initial]',
						$searchedWordStore.name.length > 15 && 'text-xl',
					)}
				>
					{@html $searchedWordStore?.furigana}
				</p>

				{#if showTranslation}
					<p
						transition:slide={{ duration: 300, delay: 0, easing: quintOut, axis: 'y' }}
						class="absolute bottom-full left-0 right-0 mb-2 text-balance text-center"
					>
						{$searchedWordStore?.meaning}
					</p>
				{/if}
			</div>
		{:else}
			<p class="text-balance text-5xl leading-normal tracking-widest">
				{$searchedWordStore.name}
			</p>
		{/if}
	</div>

	<div class="flex flex-wrap justify-center gap-4">
		<Button on:click={showHistory} disabled={data.searches.length === 0}>
			<History class="color-current mr-2 size-5" />
			<span>See History</span>
		</Button>

		<Button
			on:click={(e) => {
				e.preventDefault();
				showTranslation = !showTranslation;
			}}
			variant="outline"
			disabled={data.searches.length === 0}
		>
			Translation
		</Button>

		{#if $searchedWordStore?.flashcardBox}
			<Button
				variant="outline"
				on:click={async () => {
					const flashcardCollection = await pocketbase
						.collection('flashcardBoxes')
						.getFirstListItem(`id = "${$searchedWordStore?.flashcardBox}"`, {
							fields: 'flashcardCollection',
						});

					if (flashcardCollection)
						localStorage.setItem(
							'currentFlashcardCollectionId',
							flashcardCollection.flashcardCollection,
						);

					goto(`/flashcards/${$searchedWordStore?.flashcardBox}`);
				}}
			>
				Go to Flashcard
			</Button>
		{/if}

		<CallBackButton />
	</div>
</section>
