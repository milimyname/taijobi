<script lang="ts">
	import Badge from '$lib/components/ui/badge/badge.svelte';
	import { Button } from '$lib/components/ui/button';
	import * as DrawerDialog from '$lib/components/ui/drawerDialog';
	import type { RecordModel } from 'pocketbase';
	import * as Card from '$lib/components/ui/card';
	import {
		nestedSearchDrawerOpen,
		openHistory,
		selectedSearchFlashcards,
		searchedWordStore,
	} from '$lib/utils/stores';
	import { ScrollArea } from '$lib/components/ui/scroll-area/index';
	import { goto } from '$app/navigation';
	import { ArrowDown01, ArrowDown10, Plus } from 'lucide-svelte';
	import Input from '$lib/components/ui/input/input.svelte';
	import * as Tooltip from '$lib/components/ui/tooltip';
	import { CircleX } from 'lucide-svelte';
	import { pocketbase } from '$lib/utils/pocketbase';
	import NestedSearchDrawerDialog from './nested-search-drawer-dialog.svelte';
	import { cn, isDesktop } from '$lib/utils';

	export let searches: RecordModel[];

	let sortedByDate = true;
	let inputValue = '';
	let isCreatingNewFlashcardBox = false;

	function onCloseDrawer() {
		setTimeout(() => ($openHistory = false), 100);
	}

	function onClickOutSideClick(e: PointerEvent | MouseEvent | TouchEvent) {
		let eventTarget = (
			(e as TouchEvent).changedTouches ? (e as TouchEvent).changedTouches[0].target : e.target
		) as Element;

		// If the user clicks on the leave button, don't move the card
		if (eventTarget.closest('.drawerNested')) return;

		// If nestedSearchDrawerOpen is true, don't close the drawer
		if ($nestedSearchDrawerOpen) return;

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

	$: sortedSearches = (() => {
		if (!searches) return [];

		// Filter the searches based on the input value
		if (inputValue !== '') {
			return searches.filter((search: RecordModel) =>
				search?.expand?.flashcard?.name.toLowerCase().includes(inputValue.toLowerCase()),
			);
		}

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

<DrawerDialog.Root open={$openHistory} onOutsideClick={onClickOutSideClick} onClose={onCloseDrawer}>
	<DrawerDialog.Content className="w-full  md:max-w-2xl p-0">
		<DrawerDialog.Header class="text-left p-5 pb-0 space-y-2 max-md:mb-5">
			<DrawerDialog.Title>Search History</DrawerDialog.Title>
			<DrawerDialog.Description className="flex gap-1 sm:gap-2">
				<Button
					size="icon"
					variant="outline"
					class="max-w-14 w-12"
					on:click={() => (isCreatingNewFlashcardBox = !isCreatingNewFlashcardBox)}
				>
					<Plus class="size-4" />
				</Button>
				<Button
					size="icon"
					variant="outline"
					class="max-w-14 w-12"
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
				<NestedSearchDrawerDialog />
			{/if}
		</DrawerDialog.Header>
		<ScrollArea class="h-[32rem] w-full">
			<div class="grid md:grid-cols-3 gap-2 p-5 pt-0">
				{#each sortedSearches as search}
					<Card.Root
						class={cn(
							'cursor-pointer hover:shadow-md transition-shadow duration-300 ease-linear flex flex-col justify-between',
							$searchedWordStore.id === search?.expand?.flashcard?.id && 'border-primary border-2',
						)}
					>
						<Card.Header class="relative">
							<Card.Title>{search?.expand?.flashcard?.name}</Card.Title>

							{#if sortedSearches.length > 0}
								<Button
									size="icon"
									variant="none"
									class="absolute right-2 top-1 size-fit"
									disabled={isCreatingNewFlashcardBox}
									on:click={() => deleteFlashcardFromSearch(search)}
								>
									<CircleX class="size-4 text-red-700" />
								</Button>
							{/if}
						</Card.Header>
						<Card.Content class="flex flex-wrap gap-1">
							<Tooltip.Root>
								<Tooltip.Trigger>
									<Badge>
										{search.searchQuery}
									</Badge>
								</Tooltip.Trigger>
								<Tooltip.Content>
									<p>Search Keyword</p>
								</Tooltip.Content>
							</Tooltip.Root>

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

		<DrawerDialog.Footer className="md:hidden px-5">
			{#if $selectedSearchFlashcards.length > 0}
				<NestedSearchDrawerDialog />
			{/if}
			<DrawerDialog.Close asChild let:builder>
				<Button builders={[builder]} variant="outline">Cancel</Button>
			</DrawerDialog.Close>
		</DrawerDialog.Footer>
	</DrawerDialog.Content>
</DrawerDialog.Root>
