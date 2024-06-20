<script lang="ts">
	import Badge from '$lib/components/ui/badge/badge.svelte';
	import { Button } from '$lib/components/ui/button';
	import * as DrawerDialog from '$lib/components/ui/drawerDialog';
	import type { RecordModel } from 'pocketbase';
	import * as Card from '$lib/components/ui/card';
	import { openConjugation } from '$lib/utils/stores';
	import { ScrollArea } from '$lib/components/ui/scroll-area/index';
	import * as Accordion from '$lib/components/ui/accordion';

	export let flashcardBoxes: RecordModel[] = [];

	let custom = false;

	function onCloseDrawer() {
		setTimeout(() => ($openConjugation = false), 100);
	}

	$: sortedFlashcardBoxes = flashcardBoxes?.filter((box) => {
		if (custom) return box.collectionType === 'custom' || box.collectionType === 'original';
		else return box.collectionType === 'custom';
	});
</script>

<DrawerDialog.Root open={$openConjugation} onOutsideClick={onCloseDrawer} onClose={onCloseDrawer}>
	<DrawerDialog.Content className="px-5">
		<DrawerDialog.Header class="text-left p-0 space-y-2 max-md:mb-5">
			<DrawerDialog.Title>Create New Conjugation List (WIP)</DrawerDialog.Title>
			<DrawerDialog.Description className="flex gap-2">
				<Button variant="outline" on:click={() => (custom = !custom)}>
					{custom ? 'Custom + Original' : 'Custom'}
				</Button>
			</DrawerDialog.Description>
		</DrawerDialog.Header>
		<ScrollArea class="h-[32rem] w-full overflow-auto [&>div>div[style]]:!block">
			<div>
				{#each sortedFlashcardBoxes as box}
					<Accordion.Root>
						<Accordion.Item value={box.flashcardBoxName} class="border-0">
							<Accordion.Trigger>{box.flashcardBoxName}</Accordion.Trigger>
							<Accordion.Content>
								<ScrollArea class="w-[40rem] whitespace-nowrap" orientation="horizontal">
									<div class="flex w-max space-x-4">
										{#each box.flashcards as flashcard}
											<Card.Root
												class="cursor-pointer hover:shadow-md transition-shadow duration-300 ease-linear flex flex-col justify-between"
											>
												<Card.Header>
													<Card.Title class="text-center">{flashcard.name}</Card.Title>
												</Card.Header>
												<Card.Content class="space-y-1">
													<p>{flashcard.meaning}</p>
													<Badge variant="outline">
														{flashcard.type}
													</Badge>
												</Card.Content>
												<Card.Footer>
													<Button variant="outline" class="w-full">Select</Button>
												</Card.Footer>
											</Card.Root>
										{/each}
									</div>
								</ScrollArea>
							</Accordion.Content>
						</Accordion.Item>
					</Accordion.Root>
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
