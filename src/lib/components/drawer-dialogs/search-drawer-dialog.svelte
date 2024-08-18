<script lang="ts">
	import Badge from '$lib/components/ui/badge/badge.svelte';
	import { Button } from '$lib/components/ui/button';
	import * as DrawerDialog from '$lib/components/ui/drawer-dialog';
	import type { RecordModel } from 'pocketbase';
	import * as Card from '$lib/components/ui/card';
	import {
		nestedSearchDrawerOpen,
		openHistory,
		selectedSearchFlashcards,
		searchedWordStore,
		deleteDrawerDialogOpen,
	} from '$lib/utils/stores';
	import { ScrollArea } from '$lib/components/ui/scroll-area/index';
	import { goto } from '$app/navigation';
	import { ArrowDown01, ArrowDown10, EllipsisVertical, Plus } from 'lucide-svelte';
	import Input from '$lib/components/ui/input/input.svelte';
	import * as Tooltip from '$lib/components/ui/tooltip';
	import { CircleX } from 'lucide-svelte';
	import { pocketbase } from '$lib/utils/pocketbase';
	import NestedSearchDrawerDialog from './nested-search-drawer-dialog.svelte';
	import { cn, isDesktop } from '$lib/utils';
	import DeleteDrawerAlertDialog from '$lib/components/drawer-alert-dialogs/delete-drawer-alert-dialog.svelte';
	import { getContext } from 'svelte';
	import { toast } from 'svelte-sonner';
	import DeleteTrashButton from '$lib/components/delete-trash-button.svelte';
	import { quintOut } from 'svelte/easing';
	import { slide } from 'svelte/transition';
	import * as DropdownMenu from '$lib/components/ui/dropdown-menu';

	export let searches: RecordModel[];

	let sortedByDate = true;
	let inputValue = '';
	let isCreatingNewFlashcardBox = false;
	let loading = false;
	let clickedDeletedCompletely = false;
	let currentSearch: RecordModel | null = null;

	function onCloseDrawer() {
		setTimeout(() => ($openHistory = false), 150);
	}

	function onClickOutSideClick(e: PointerEvent | MouseEvent | TouchEvent) {
		let eventTarget = (
			(e as TouchEvent).changedTouches ? (e as TouchEvent).changedTouches[0].target : e.target
		) as Element;

		// If the user clicks on the leave button, don't move the card
		if (eventTarget.closest('.drawerNested')) return;

		// If nestedSearchDrawerOpen is true, don't close the drawer
		if ($nestedSearchDrawerOpen) return;

		// If deleteDrawerDialogOpen is true, don't close the drawer
		if ($deleteDrawerDialogOpen) return;

		onCloseDrawer();
	}

	function selectFlashcard(search: RecordModel) {
		$selectedSearchFlashcards = [...$selectedSearchFlashcards, search];
	}

	async function deleteFlashcardFromSearch(search: RecordModel) {
		try {
			await pocketbase.collection('searches').delete(search.id);

			searches = searches.filter((s) => s.id !== search.id);
		} catch (error) {
			console.error(error);
		}
	}

	const searchedFlashcardsIds = getContext<string[]>('searchedFlashcardsIds');
	const searchesIds = getContext<string[]>('searchesIds');

	async function deleteFromHistory() {
		loading = true;
		try {
			await Promise.all(
				searchedFlashcardsIds?.map(async (id: string) => {
					await pocketbase.collection('flashcard').update(id, {
						searches: [],
					});
				}),
			);
		} catch (error) {
			console.error('Error deleting search history:', error);
		}

		try {
			await Promise.all(
				searchesIds?.map(async (id: string) => {
					await pocketbase.collection('searches').delete(id);
				}),
			);
		} catch (error) {
			console.error('Error deleting search history:', error);
			toast.error('Error deleting search history. Please try again later.');
			return;
		}

		$openHistory = false;
		loading = false;

		setTimeout(() => ($deleteDrawerDialogOpen = false), 150);

		toast.success('Searches deleted successfully. Redirecting to the home page...');

		goto('/');
	}

	async function deleteCompletely() {
		loading = true;
		try {
			await pocketbase.collection('searches').delete(currentSearch.id);
		} catch (error) {
			console.error('Error deleting search history:', error);
		}

		try {
			await pocketbase.collection('flashcard').delete(currentSearch.flashcard);
		} catch (error) {
			console.error('Error deleting search history:', error);
			toast.error('Error deleting search history. Please try again later.');
			return;
		}

		$openHistory = false;
		loading = false;
		clickedDeletedCompletely = false;

		setTimeout(() => ($deleteDrawerDialogOpen = false), 150);

		toast.success('Search and its flashcard deleted completely.');
	}

	$: sortedSearches = (() => {
		if (!searches) return [];

		// Filter the searches based on the input value
		if (inputValue !== '') {
			return searches.filter((search: RecordModel) =>
				search?.expand?.flashcard?.name.toLowerCase().includes(inputValue.toLowerCase()),
			);
		}
		// Distinct the searches based on the flashcard id
		searches = searches.filter(
			(search: RecordModel, index: number, self: RecordModel[]) =>
				index ===
				self.findIndex((s) => s.expand && s.expand.flashcard.id === search.expand.flashcard.id),
		);

		return sortedByDate
			? searches.sort(
					(a: RecordModel, b: RecordModel) =>
						Number(new Date(b.created)) - Number(new Date(a.created)),
				)
			: searches.sort(
					(a: RecordModel, b: RecordModel) =>
						Number(new Date(a.created)) - Number(new Date(b.created)),
				);
	})();
</script>

{#if clickedDeletedCompletely}
	<DeleteDrawerAlertDialog onClick={deleteCompletely} />
{:else}
	<DeleteDrawerAlertDialog onClick={deleteFromHistory} />
{/if}

<NestedSearchDrawerDialog />

<DrawerDialog.Root open={$openHistory} onOutsideClick={onClickOutSideClick} onClose={onCloseDrawer}>
	<DrawerDialog.Content
		className={cn('w-full max-h-[90dvh] md:max-w-2xl p-0', $deleteDrawerDialogOpen && 'z-60')}
	>
		<DrawerDialog.Header class="space-y-2 p-5 pb-0 text-left max-md:mb-5">
			<DrawerDialog.Title className="flex py-2 justify-between items-center">
				<span> Search History </span>
				<DeleteTrashButton {loading} />
			</DrawerDialog.Title>
			<DrawerDialog.Description className="flex gap-1 sm:gap-2">
				<Button
					size="icon"
					variant="outline"
					class="w-12 max-w-14"
					on:click={() => (isCreatingNewFlashcardBox = !isCreatingNewFlashcardBox)}
				>
					<Plus class="size-4" />
				</Button>
				<Button
					size="icon"
					variant="outline"
					class="w-12 max-w-14"
					on:click={() => (sortedByDate = !sortedByDate)}
				>
					{#if sortedByDate}
						<ArrowDown10 class="size-4" />
					{:else}
						<ArrowDown01 class="size-4" />
					{/if}
				</Button>

				<Input placeholder="Flashcard Name" bind:value={inputValue} />
			</DrawerDialog.Description>
			{#if $selectedSearchFlashcards.length > 0 && $isDesktop}
				<div transition:slide={{ duration: 300, easing: quintOut, axis: 'y' }} class="w-full">
					<Button class="w-full" on:click={() => ($nestedSearchDrawerOpen = true)}>
						Create Flashcard Box
					</Button>
				</div>
			{/if}
		</DrawerDialog.Header>
		<ScrollArea class="h-[32rem] w-full">
			<div class="grid gap-2 p-5 pt-0 md:grid-cols-3">
				{#each sortedSearches as search}
					<Card.Root
						class={cn(
							'flex cursor-pointer select-text flex-col justify-between transition-shadow duration-300 ease-linear hover:shadow-md',
							$searchedWordStore.id === search?.expand?.flashcard?.id && 'border-2 border-primary',
						)}
					>
						<Card.Header class="relative">
							<Card.Title class="line-clamp-3	flex items-start justify-between gap-2">
								<p class="line-clamp-3">{search?.expand?.flashcard?.name}</p>

								{#if sortedSearches.length > 0}
									<DropdownMenu.Root>
										<DropdownMenu.Trigger>
											<Button
												size="icon"
												variant="none"
												disabled={isCreatingNewFlashcardBox ||
													$searchedWordStore.id === search?.expand?.flashcard?.id}
											>
												<EllipsisVertical class="size-4" />
											</Button>
										</DropdownMenu.Trigger>

										<DropdownMenu.Content>
											<DropdownMenu.Group>
												<DropdownMenu.Item on:click={() => deleteFlashcardFromSearch(search)}>
													Delete From Search History
												</DropdownMenu.Item>
												<DropdownMenu.Item
													on:click={() => {
														currentSearch = search;
														clickedDeletedCompletely = true;
														$deleteDrawerDialogOpen = true;
													}}
												>
													Delete Completely
												</DropdownMenu.Item>
											</DropdownMenu.Group>
										</DropdownMenu.Content>
									</DropdownMenu.Root>
								{/if}
							</Card.Title>
						</Card.Header>
						<Card.Content class="flex flex-wrap gap-1 overflow-auto">
							{#if search?.expand?.flashcard?.name !== search.searchQuery && search.searchQuery !== ''}
								<Tooltip.Root>
									<ScrollArea class="max-w-fit" orientation="horizontal">
										<Tooltip.Trigger>
											<Badge class="truncate">
												{search.searchQuery}
											</Badge>
										</Tooltip.Trigger>
									</ScrollArea>
									<Tooltip.Content>
										<p>Search Keyword</p>
									</Tooltip.Content>
								</Tooltip.Root>
							{/if}

							{#if search?.expand?.flashcard?.expand?.flashcardBox?.name}
								<Tooltip.Root>
									<Tooltip.Trigger>
										<Badge variant="outline" class="truncate">
											{search?.expand?.flashcard?.expand?.flashcardBox?.name}
										</Badge>
									</Tooltip.Trigger>
									<Tooltip.Content>
										<p>Flashcard Box Name</p>
									</Tooltip.Content>
								</Tooltip.Root>
							{/if}

							<Tooltip.Root>
								<Tooltip.Trigger>
									<Badge variant="outline">
										{new Date(search?.created).toLocaleDateString()}
									</Badge>
								</Tooltip.Trigger>
								<Tooltip.Content>
									<p>Search Date</p>
								</Tooltip.Content>
							</Tooltip.Root>
						</Card.Content>
						<Card.Footer>
							{#if !isCreatingNewFlashcardBox}
								<DrawerDialog.Close asChild let:builder>
									<Button
										builders={[builder]}
										variant="outline"
										class="w-full"
										on:click={() => {
											setTimeout(() => {
												$openHistory = false;
												goto(`/search/${search.id}`);
											}, 100);
										}}
									>
										See Details
									</Button>
								</DrawerDialog.Close>
							{:else if !$selectedSearchFlashcards.includes(search)}
								<Button variant="outline" class="w-full" on:click={() => selectFlashcard(search)}>
									Select
								</Button>
							{:else}
								<Button
									variant="selected"
									class="w-full"
									on:click={() => {
										$selectedSearchFlashcards = $selectedSearchFlashcards.filter(
											(selectedSearch) => selectedSearch !== search,
										);
									}}
								>
									Selected
								</Button>
							{/if}
						</Card.Footer>
					</Card.Root>
				{/each}
			</div>
		</ScrollArea>
		<DrawerDialog.Footer className="md:hidden px-5 max-md:shadow-search-drawer-footer z-10">
			{#if $selectedSearchFlashcards.length > 0}
				<div transition:slide={{ duration: 300, easing: quintOut, axis: 'y' }} class="w-full">
					<Button class="w-full" on:click={() => ($nestedSearchDrawerOpen = true)}>
						Create Flashcard Box
					</Button>
				</div>
			{/if}
			<DrawerDialog.Close asChild let:builder>
				<Button builders={[builder]} variant="outline">Cancel</Button>
			</DrawerDialog.Close>
		</DrawerDialog.Footer>
	</DrawerDialog.Content>
</DrawerDialog.Root>
