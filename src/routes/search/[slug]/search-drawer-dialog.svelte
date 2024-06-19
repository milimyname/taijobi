<script lang="ts">
	import Badge from '$lib/components/ui/badge/badge.svelte';
	import { Button } from '$lib/components/ui/button';
	import * as DrawerDialog from '$lib/components/ui/drawerDialog';
	import type { RecordModel } from 'pocketbase';
	import * as Card from '$lib/components/ui/card';
	import { openHistory } from '$lib/utils/stores';
	import { ScrollArea } from '$lib/components/ui/scroll-area/index';
	import { goto } from '$app/navigation';
	import { ArrowDown01, ArrowDown10 } from 'lucide-svelte';
	import Input from '$lib/components/ui/input/input.svelte';
	import * as Tooltip from '$lib/components/ui/tooltip';

	export let searches: RecordModel[];

	let sortedByDate = false;
	let inputValue = '';

	function onCloseDrawer() {
		setTimeout(() => ($openHistory = false), 100);
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

<DrawerDialog.Root open={$openHistory} onOutsideClick={onCloseDrawer} onClose={onCloseDrawer}>
	<DrawerDialog.Content className="px-5">
		<DrawerDialog.Header class="text-left p-0 space-y-2 max-md:mb-5">
			<DrawerDialog.Title>Search History</DrawerDialog.Title>
			<DrawerDialog.Description className="flex gap-2">
				<Button variant="outline" on:click={() => (sortedByDate = !sortedByDate)}>
					{#if sortedByDate}
						<ArrowDown10 class="size-5 mr-2" />
					{:else}
						<ArrowDown01 class="size-5 mr-2" />
					{/if}
					<span>Sorted by date</span>
				</Button>
				<Input placeholder="Flashcard Name" bind:value={inputValue} />
			</DrawerDialog.Description>
		</DrawerDialog.Header>
		<ScrollArea class="h-[32rem] w-full">
			<div class="grid md:grid-cols-2 gap-2">
				{#each sortedSearches as search}
					<Card.Root
						class="cursor-pointer hover:shadow-md transition-shadow duration-300 ease-linear flex flex-col justify-between"
					>
						<Card.Header>
							<Card.Title>{search?.expand?.flashcard?.name}</Card.Title>
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
									<Badge variant="outline">
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
							<Button
								variant="outline"
								class="w-full"
								on:click={() => {
									goto(`/search/${search.id}`);
									onCloseDrawer();
								}}
							>
								See Details
							</Button>
						</Card.Footer>
					</Card.Root>
				{/each}
			</div>
		</ScrollArea>

		<DrawerDialog.Footer className="md:hidden px-0">
			<DrawerDialog.Close asChild let:builder>
				<Button builders={[builder]} variant="outline">Cancel</Button>
			</DrawerDialog.Close>
		</DrawerDialog.Footer>
	</DrawerDialog.Content>
</DrawerDialog.Root>
