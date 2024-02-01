<script lang="ts">
	import {
		clickedEditFlashcard,
		clickedAddFlashcardCollection,
		clickedAddFlahcardBox,
		clickedFeedback,
		maxFlashcards,
		flashcardBoxes,
		swapFlashcards,
		selectQuizItemsForm,
		selectedQuizItems,
		currentBoxId
	} from '$lib/utils/stores';
	import QuizItems from './quiz-items.svelte';
	import * as Dialog from '$lib/components/ui/dialog';
	import * as Drawer from '$lib/components/ui/drawer';
	import { Button } from '$lib/components/ui/button';
	import Form from '$lib/components/forms/flashcard-collection-form.svelte';
	import { isDesktop } from '$lib/utils';
	import { page } from '$app/stores';
	import { type FlashcardCollectionSchema } from '$lib/utils/zodSchema';
	import { type SuperForm } from 'sveltekit-superforms/client';

	export let form: SuperForm<FlashcardCollectionSchema>;

	let formData = form.form;

	function onOutsideClick(e: MouseEvent) {
		//  If the user clicks on the leave button, don't move the card
		if (
			$page.url.pathname.includes('flashcards') &&
			((e.target as Element).closest('.add-btn') ||
				(e.target as Element).closest('.swap-items') ||
				(e.target as Element).closest('.edit-collection-btn'))
		)
			return;

		$clickedAddFlashcardCollection = false;
		$clickedAddFlahcardBox = false;
		$clickedEditFlashcard = false;
		$selectedQuizItems = [];
		form.reset();
	}

	$: open = $clickedAddFlashcardCollection || $clickedAddFlahcardBox;

	$: if ($clickedFeedback) {
		$clickedAddFlashcardCollection = false;
		$clickedAddFlahcardBox = false;
		$clickedEditFlashcard = false;
	}
</script>

{#if $isDesktop}
	<Dialog.Root bind:open {onOutsideClick}>
		<Dialog.Content class="z-[100] sm:max-w-[425px]">
			<Dialog.Header>
				<Dialog.Title>
					{#if $clickedEditFlashcard}
						Edit {$clickedAddFlashcardCollection ? 'collection' : 'box'}
					{:else}
						Add a new {$clickedAddFlashcardCollection ? 'collection' : 'box'}
					{/if}
				</Dialog.Title>
			</Dialog.Header>
			<Form {form}>
				<div slot="delete">
					<Dialog.Close asChild let:builder>
						<Button builders={[builder]} variant="destructive">Delete</Button>
					</Dialog.Close>
				</div>
				<div slot="update">
					<Dialog.Close asChild let:builder>
						<Button builders={[builder]}>Update</Button>
					</Dialog.Close>
				</div>
				<div slot="add">
					<Dialog.Close asChild let:builder>
						<Button builders={[builder]} class="w-full">Add</Button>
					</Dialog.Close>
				</div>

				<div slot="swap">
					<Dialog.Root>
						{#if !$clickedAddFlashcardCollection && $maxFlashcards !== '0' && $flashcardBoxes.length > 1}
							<Dialog.Trigger
								class=" w-full  items-center gap-2 rounded-md bg-gray-900 px-3.5 py-2.5 text-sm font-semibold text-white shadow-sm hover:bg-gray-800 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-gray-600"
								on:click={() => ($swapFlashcards = true)}
							>
								Swap Flashcards
							</Dialog.Trigger>
						{/if}
						<Dialog.Content class="swap-items z-[101] h-full max-h-[96%] max-w-2xl p-0">
							<QuizItems flashcardBox={$currentBoxId}>
								<Dialog.Close asChild let:builder>
									<Button
										builders={[builder]}
										on:click={() => {
											$selectQuizItemsForm = false;
											$swapFlashcards = false;
											$selectedQuizItems = [];
										}}
										variant="outline"
									>
										Cancel
									</Button>
								</Dialog.Close>
							</QuizItems>
						</Dialog.Content>
					</Dialog.Root>
				</div>
			</Form>
		</Dialog.Content>
	</Dialog.Root>
{:else}
	<Drawer.Root
		onClose={() => {
			$clickedAddFlashcardCollection = false;
			$clickedAddFlahcardBox = false;
			$clickedEditFlashcard = false;
			form.reset();
		}}
		{open}
		shouldScaleBackground
	>
		<Drawer.Portal>
			<Drawer.Content>
				<Drawer.Header class="text-left">
					<Drawer.Title>
						{#if $clickedEditFlashcard}
							Edit {$clickedAddFlashcardCollection ? 'collection' : 'box'}
						{:else}
							Add a new {$clickedAddFlashcardCollection ? 'collection' : 'box'}
						{/if}
					</Drawer.Title>
				</Drawer.Header>
				<Form {form}>
					<Button variant="destructive" slot="delete" class="w-full">Delete</Button>
					<Button slot="update" class="w-full">Update</Button>
					<Button slot="add" class="w-full">Add</Button>

					<div slot="swap">
						<Drawer.Nested>
							{#if !$clickedAddFlashcardCollection && $maxFlashcards !== '0' && $flashcardBoxes.length > 1}
								<Drawer.Trigger
									class=" w-full  items-center gap-2 rounded-md bg-gray-900 px-3.5 py-2.5 text-sm font-semibold text-white shadow-sm hover:bg-gray-800 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-gray-600"
									on:click={() => ($swapFlashcards = true)}
								>
									Swap Flashcards
								</Drawer.Trigger>
							{/if}
							<Drawer.Portal>
								<Drawer.Content
									class="select-quiz fixed bottom-0 left-0 right-0 mt-24 flex h-full max-h-[94%] flex-col rounded-t-[10px] bg-gray-100"
								>
									<QuizItems flashcardBox={$currentBoxId}>
										<Drawer.Close asChild let:builder>
											<Button
												builders={[builder]}
												on:click={() => {
													$selectQuizItemsForm = false;
													$swapFlashcards = false;
													$selectedQuizItems = [];
												}}
												variant="outline"
											>
												Cancel
											</Button>
										</Drawer.Close>
									</QuizItems>
								</Drawer.Content>
							</Drawer.Portal>
						</Drawer.Nested>
					</div>
				</Form>
				<Drawer.Footer>
					<Drawer.Close asChild let:builder>
						<Button builders={[builder]} variant="outline">Cancel</Button>
					</Drawer.Close>
				</Drawer.Footer>
			</Drawer.Content>
		</Drawer.Portal>
	</Drawer.Root>
{/if}
