<script lang="ts">
	import { Button } from '$lib/components/ui/button';
	import * as DrawerDialog from '$lib/components/ui/drawer-dialog';
	import type { RecordModel } from 'pocketbase';
	import * as Card from '$lib/components/ui/card';
	import { openConjugation, selectedConjugatingFlashcards } from '$lib/utils/stores';
	import { ScrollArea } from '$lib/components/ui/scroll-area/index';
	import * as Accordion from '$lib/components/ui/accordion';
	import type { FlashcardType } from '$lib/utils/ambient';
	import NestedConjugateDrawerDialog from './nested-conjugate-drawer-dialog.svelte';
	import { isDesktop } from '$lib/utils';
	import { getContext } from 'svelte';

	const flashcardBoxes: RecordModel[] = getContext('ogFlashcardBoxes');

	let custom = false;

	function onCloseDrawer() {
		setTimeout(() => ($openConjugation = false), 100);
	}

	function selectFlashcard(flashcard: FlashcardType) {
		$selectedConjugatingFlashcards = [...$selectedConjugatingFlashcards, flashcard];
	}

	$: sortedFlashcardBoxes = flashcardBoxes?.filter((box) => {
		if (custom) return box.collectionType === 'custom' || box.collectionType === 'original';
		else return box.collectionType === 'custom';
	});
</script>

<DrawerDialog.Root open={$openConjugation} onOutsideClick={onCloseDrawer} onClose={onCloseDrawer}>
	<DrawerDialog.Content className="w-full max-h-[90dvh] md:max-w-2xl p-0">
		<DrawerDialog.Header class="text-left p-5 pb-0 space-y-2 max-md:mb-5">
			<DrawerDialog.Title>Create New Conjugation List (WIP)</DrawerDialog.Title>
			<DrawerDialog.Description className="flex gap-2">
				<Button variant="outline" on:click={() => (custom = !custom)}>
					{custom ? 'Custom + Original' : 'Custom'}
				</Button>
			</DrawerDialog.Description>
			{#if $selectedConjugatingFlashcards.length > 0 && $isDesktop}
				<NestedConjugateDrawerDialog />
			{/if}
		</DrawerDialog.Header>
		<ScrollArea class="h-[32rem] w-full overflow-auto px-0">
			<div>
				{#each sortedFlashcardBoxes as box}
					<Accordion.Root>
						<Accordion.Item value={box.flashcardBoxName} class="border-0">
							<Accordion.Trigger class="px-5">{box.flashcardBoxName}</Accordion.Trigger>
							<Accordion.Content>
								<ScrollArea class="w-[40rem] whitespace-nowrap" orientation="horizontal">
									<div class="flex w-max space-x-4 pl-5 pb-3">
										{#each box.flashcards as flashcard}
											<Card.Root
												class="cursor-pointer hover:shadow-md transition-shadow duration-300 ease-linear flex flex-col justify-between"
											>
												<Card.Header>
													<Card.Title class="text-center">{flashcard.name}</Card.Title>
												</Card.Header>
												<Card.Content class="space-y-1">
													<p>{flashcard.meaning}</p>
												</Card.Content>
												<Card.Footer>
													{#if !$selectedConjugatingFlashcards.includes(flashcard)}
														<Button
															variant="outline"
															class="w-full"
															on:click={() => selectFlashcard(flashcard)}
														>
															Select
														</Button>
													{:else}
														<Button
															variant="selected"
															class="w-full"
															on:click={() => {
																$selectedConjugatingFlashcards =
																	$selectedConjugatingFlashcards.filter(
																		(selectedSearch) => selectedSearch !== flashcard,
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
							</Accordion.Content>
						</Accordion.Item>
					</Accordion.Root>
				{/each}
			</div>
		</ScrollArea>

		<DrawerDialog.Footer className="md:hidden px-5">
			{#if $selectedConjugatingFlashcards.length > 0}
				<NestedConjugateDrawerDialog />
			{/if}
			<DrawerDialog.Close asChild let:builder>
				<Button builders={[builder]} variant="outline">Cancel</Button>
			</DrawerDialog.Close>
		</DrawerDialog.Footer>
	</DrawerDialog.Content>
</DrawerDialog.Root>
