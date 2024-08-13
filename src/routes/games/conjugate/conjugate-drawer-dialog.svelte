<script lang="ts">
	import { Button } from '$lib/components/ui/button';
	import * as DrawerDialog from '$lib/components/ui/drawer-dialog';
	import type { RecordModel } from 'pocketbase';
	import * as Card from '$lib/components/ui/card';
	import {
		openConjugation,
		selectedConjugatingFlashcards,
		nestedSearchDrawerOpen,
	} from '$lib/utils/stores';
	import { ScrollArea } from '$lib/components/ui/scroll-area/index';
	import * as Accordion from '$lib/components/ui/accordion';
	import type { FlashcardType } from '$lib/utils/ambient';
	import NestedConjugateDrawerDialog from './nested-conjugate-drawer-dialog.svelte';
	import { isDesktop } from '$lib/utils';
	import { getContext } from 'svelte';
	import Input from '$lib/components/ui/input/input.svelte';
	import { quintOut } from 'svelte/easing';
	import { slide } from 'svelte/transition';

	const flashcardBoxes: RecordModel[] = getContext('ogFlashcardBoxes');

	let custom = false;
	let inputValue = '';
	let accordionDefaultValues: string[] = [];

	function onCloseDrawer() {
		if ($nestedSearchDrawerOpen) return;

		setTimeout(() => ($openConjugation = false), 100);
	}

	function selectFlashcard(flashcard: FlashcardType) {
		$selectedConjugatingFlashcards = [...$selectedConjugatingFlashcards, flashcard];
	}

	$: sortedFlashcardBoxes = flashcardBoxes
		?.map((box) => {
			// Filter the flashcards within each box
			const filteredFlashcards = box.flashcards.filter(
				(flashcard) =>
					inputValue === '' ||
					flashcard.name.toLowerCase().includes(inputValue.toLowerCase()) ||
					flashcard.meaning.toLowerCase().includes(inputValue.toLowerCase()),
			);

			// Create a new box object with filtered flashcards
			return {
				...box,
				flashcards: filteredFlashcards,
			};
		})
		.filter((box, arr) => {
			// Keep the box if it has matching flashcards and meets the custom/original criteria
			const hasFlashcards = box.flashcards.length > 0;
			const meetsCustomCriteria = custom
				? box.collectionType === 'custom' || box.collectionType === 'original'
				: box.collectionType === 'custom';

			return hasFlashcards && meetsCustomCriteria;
		});

	$: accordionDefaultValues =
		inputValue !== '' ? sortedFlashcardBoxes.map((box) => box?.flashcardBoxName) : []; // Empty array when no input, allowing accordions to be closed
</script>

<NestedConjugateDrawerDialog />

<DrawerDialog.Root open={$openConjugation} onOutsideClick={onCloseDrawer} onClose={onCloseDrawer}>
	<DrawerDialog.Content className="w-full max-h-[90dvh] md:max-w-2xl p-0">
		<DrawerDialog.Header class="space-y-2 p-5 pb-0 text-left max-md:mb-5">
			<DrawerDialog.Title>Create New Conjugation List (WIP)</DrawerDialog.Title>
			<DrawerDialog.Description className="flex gap-2">
				<Button variant="outline" on:click={() => (custom = !custom)}>
					{custom ? 'Custom + Original' : 'Custom'}
				</Button>
				<Input placeholder="Meaning or japanese name" bind:value={inputValue} />
			</DrawerDialog.Description>

			{#if $selectedConjugatingFlashcards.length > 0 && $isDesktop}
				<div transition:slide={{ duration: 300, easing: quintOut, axis: 'y' }} class="w-full">
					<Button class="w-full" on:click={() => ($nestedSearchDrawerOpen = true)}>
						Create Conjugation Quiz
					</Button>
				</div>
			{/if}
		</DrawerDialog.Header>
		<ScrollArea class="h-[32rem] w-full overflow-auto px-0">
			<div>
				<Accordion.Root multiple value={accordionDefaultValues}>
					{#each sortedFlashcardBoxes as box}
						<Accordion.Item value={box?.flashcardBoxName} class="border-0">
							<Accordion.Trigger class="px-5">{box?.flashcardBoxName}</Accordion.Trigger>
							<Accordion.Content>
								<ScrollArea class="w-[40rem] whitespace-nowrap" orientation="horizontal">
									<div class="flex w-max space-x-4 pb-3 pl-5">
										{#each box.flashcards as flashcard}
											<Card.Root
												class="flex cursor-pointer flex-col justify-between transition-shadow duration-300 ease-linear hover:shadow-md"
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
					{/each}
				</Accordion.Root>
			</div>
		</ScrollArea>

		<DrawerDialog.Footer className="md:hidden px-5 search-drawer-footer z-10">
			{#if $selectedConjugatingFlashcards.length > 0}
				<div transition:slide={{ duration: 300, easing: quintOut, axis: 'y' }} class="w-full">
					<Button class="w-full" on:click={() => ($nestedSearchDrawerOpen = true)}>
						Create Conjugation Quiz
					</Button>
				</div>
			{/if}
			<DrawerDialog.Close asChild let:builder>
				<Button builders={[builder]} variant="outline">Cancel</Button>
			</DrawerDialog.Close>
		</DrawerDialog.Footer>
	</DrawerDialog.Content>
</DrawerDialog.Root>
