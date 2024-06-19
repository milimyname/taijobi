<script lang="ts">
	import Badge from '$lib/components/ui/badge/badge.svelte';
	import { Button } from '$lib/components/ui/button';
	import * as DrawerDialog from '$lib/components/ui/drawerDialog';
	import type { RecordModel } from 'pocketbase';
	import * as Card from '$lib/components/ui/card';
	import { openHistory } from '$lib/utils/stores';
	import ScrollArea from '$lib/components/ui/scroll-area/scroll-area.svelte';
	import { goto } from '$app/navigation';

	export let searches: RecordModel[];

	function onCloseDrawer() {
		setTimeout(() => ($openHistory = false), 100);
	}
</script>

<DrawerDialog.Root open={$openHistory} onOutsideClick={onCloseDrawer} onClose={onCloseDrawer}>
	<DrawerDialog.Content className="px-5 space-y-5">
		<DrawerDialog.Header class="text-left p-0">
			<DrawerDialog.Title>Search History</DrawerDialog.Title>
			<!-- <DrawerDialog.Description>
				{#if correctAnswers === total}
					You got all {total} questions correct!
				{:else}
					You got {correctAnswers} out of {total} questions correct.
				{/if}
			</DrawerDialog.Description> -->
		</DrawerDialog.Header>
		<ScrollArea class="h-[32rem] w-full">
			<div class="grid md:grid-cols-2 gap-2">
				{#each searches as search}
					<Card.Root
						class="cursor-pointer hover:shadow-md transition-shadow duration-300 ease-linear flex flex-col justify-between"
					>
						<Card.Header>
							<Card.Title>{search?.expand?.flashcard?.name}</Card.Title>
						</Card.Header>
						<Card.Content class="flex flex-wrap gap-1">
							<Badge>
								{search.searchQuery}
							</Badge>
							<Badge variant="outline">
								{search?.expand?.flashcard?.expand?.flashcardBox?.name}
							</Badge>
							<Badge variant="outline">
								{new Date(search?.expand?.flashcard?.created).toLocaleDateString()}
							</Badge>
						</Card.Content>
						<Card.Footer class="">
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

		<!-- <But
         ton on:click={startOver} class="max-sm:hidden">Start Over</But> -->
		<DrawerDialog.Footer className="md:hidden px-0">
			<!-- <Button on:click={startOver}>Start Over</Button> -->
			<DrawerDialog.Close asChild let:builder>
				<Button builders={[builder]} variant="outline">Cancel</Button>
			</DrawerDialog.Close>
		</DrawerDialog.Footer>
	</DrawerDialog.Content>
</DrawerDialog.Root>
