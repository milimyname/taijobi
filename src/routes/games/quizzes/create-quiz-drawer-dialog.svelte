<script lang="ts">
	import { Button } from '$lib/components/ui/button';
	import * as DrawerDialog from '$lib/components/ui/drawer-dialog';
	import type { RecordModel } from 'pocketbase';
	import * as Card from '$lib/components/ui/card';
	import { openConjugation, clickedQuizForm, maxFlashcards } from '$lib/utils/stores';
	import { ScrollArea } from '$lib/components/ui/scroll-area/index';
	import Input from '$lib/components/ui/input/input.svelte';
	import { pocketbase } from '$lib/utils/pocketbase';
	import { page } from '$app/stores';
	import * as Tooltip from '$lib/components/ui/tooltip';
	import Badge from '$lib/components/ui/badge/badge.svelte';
	import { type Infer, type SuperForm } from 'sveltekit-superforms';
	import { type QuizSchema } from '$lib/utils/zodSchema';
	import QuizFormUI from '$lib/components/forms/quiz-form-ui.svelte';
	import { getContext } from 'svelte';

	let flashcardBoxes: RecordModel[] = [];

	let quizForm: SuperForm<Infer<QuizSchema>> = getContext('quizForm');

	let custom = false;
	let inputValue = '';

	function onCloseDrawer() {
		setTimeout(() => ($openConjugation = false), 100);
	}

	function onClickOutSideClick(e: PointerEvent | MouseEvent | TouchEvent) {
		if ($clickedQuizForm) return;
		onCloseDrawer();
	}

	let quizFormData = quizForm.form;

	async function getFlashcardBoxes() {
		try {
			const collections = await pocketbase.collection('flashcardCollections').getFullList({
				filter: `userId = "${$page.data.user?.id}" || type = "original"`,
				expand: 'flashcardBoxes',
				fields: 'type,expand',
			});

			// Get the flashcard boxes
			flashcardBoxes = collections
				.filter((collection) => collection.expand)
				.flatMap((collection) => {
					return collection.expand.flashcardBoxes.map((box) => {
						return {
							...box,
							collectionType: collection.type,
						};
					});
				});
		} catch (e) {
			console.error(e);
		}
	}

	function clickOnQuizForm(box: RecordModel) {
		$clickedQuizForm = true;
		$openConjugation = false;

		$quizFormData.flashcardBox = box.id;
		$quizFormData.name = box.name;
		$maxFlashcards = box.flashcards.length;
	}

	$: if ($openConjugation) getFlashcardBoxes();

	$: sortedFlashcardBoxes = flashcardBoxes.filter((box) => {
		if (flashcardBoxes.length === 0) return [];

		// Filter by input value
		if (inputValue !== '') return box?.name.toLowerCase().includes(inputValue.toLowerCase());

		// Check if the box meets the custom/original criteria
		const meetsCustomCriteria = custom
			? box.collectionType === 'custom' || box.collectionType === 'original'
			: box.collectionType === 'custom';

		return meetsCustomCriteria;
	});
</script>

<QuizFormUI form={quizForm} />

<DrawerDialog.Root
	open={$openConjugation}
	onClose={onCloseDrawer}
	onOutsideClick={onClickOutSideClick}
>
	<DrawerDialog.Content className="w-full max-h-[90dvh] md:max-w-2xl p-0">
		<DrawerDialog.Header class="space-y-4 p-5 pb-0 text-left max-md:mb-5">
			<DrawerDialog.Title>Create Quiz</DrawerDialog.Title>
			<DrawerDialog.Description className="flex gap-2">
				<Button variant="outline" on:click={() => (custom = !custom)}>
					{custom ? 'Custom + Original' : 'Custom'}
				</Button>
				<Input placeholder="Meaning or japanese name" bind:value={inputValue} />
			</DrawerDialog.Description>
		</DrawerDialog.Header>
		<ScrollArea class="h-[32rem] w-full px-0">
			<div class="grid grid-cols-1 gap-2 px-5 pb-5 md:grid-cols-3">
				{#each sortedFlashcardBoxes as box}
					<Card.Root
						class="flex cursor-pointer flex-col justify-between transition-shadow duration-300 ease-linear hover:shadow-md"
					>
						<button
							class="flex h-full flex-col justify-between"
							on:click={() => clickOnQuizForm(box)}
						>
							<Card.Header>
								<Card.Title>{box?.name}</Card.Title>
							</Card.Header>

							{#if box?.description}
								<Card.Content class="space-y-1">
									<p class="line-clamp-1">{box?.description}</p>
								</Card.Content>
							{/if}

							<Card.Footer class="flex gap-1">
								<Tooltip.Root>
									<Tooltip.Trigger>
										<Badge variant="outline">
											{box.flashcards.length}
										</Badge>
									</Tooltip.Trigger>
									<Tooltip.Content>
										<p>Flashcards</p>
									</Tooltip.Content>
								</Tooltip.Root>

								<Tooltip.Root>
									<Tooltip.Trigger>
										<Badge variant="outline">
											{new Date(box?.created).toLocaleDateString()}
										</Badge>
									</Tooltip.Trigger>
									<Tooltip.Content>
										<p>Quiz Created Date</p>
									</Tooltip.Content>
								</Tooltip.Root>
							</Card.Footer>
						</button>
					</Card.Root>
				{/each}
			</div>
		</ScrollArea>

		<DrawerDialog.Footer className="md:hidden px-5 search-drawer-footer z-10">
			<DrawerDialog.Close asChild let:builder>
				<Button builders={[builder]} variant="outline">Cancel</Button>
			</DrawerDialog.Close>
		</DrawerDialog.Footer>
	</DrawerDialog.Content>
</DrawerDialog.Root>
