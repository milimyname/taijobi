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

	function onClose() {
		setTimeout(() => {
			$clickedAddFlashcardCollection = false;
			$clickedAddFlahcardBox = false;
			$clickedEditFlashcard = false;
			$selectedQuizItems = [];
			form.reset();
		}, 100);
	}

	function onOutsideClick(e: PointerEvent | MouseEvent | TouchEvent) {
		let eventTarget = (
			(e as TouchEvent).changedTouches ? (e as TouchEvent).changedTouches[0].target : e.target
		) as Element;

		// If the user clicks on the leave button, don't move the card
		if (
			($page.url.pathname.includes('flashcards') && eventTarget.closest('.add-btn')) ||
			eventTarget.closest('.swap-items') ||
			eventTarget.closest('.edit-collection-btn')
		)
			return;

		onClose();
	}

	$: open = $clickedAddFlashcardCollection || $clickedAddFlahcardBox;

	$: if ($clickedFeedback) {
		$clickedAddFlashcardCollection = false;
		$clickedAddFlahcardBox = false;
		$clickedEditFlashcard = false;
	}
</script>

{#if $isDesktop}
	<Dialog.Root bind:open={$swapFlashcards}>
		<Dialog.Content class="swap-items z-[101] h-1/2 max-w-2xl p-0">
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

	<Dialog.Root bind:open {onOutsideClick}>
		<Dialog.Content class="z-[100] sm:max-w-[425px]">
			<Dialog.Header class="flex flex-row items-center">
				<Dialog.Title>
					{#if $clickedEditFlashcard}
						Edit {$clickedAddFlashcardCollection ? 'collection' : 'box'}
					{:else}
						Add a new {$clickedAddFlashcardCollection ? 'collection' : 'box'}
					{/if}
				</Dialog.Title>
				{#if !$clickedAddFlashcardCollection && $maxFlashcards !== '0' && $flashcardBoxes.length > 1}
					<button class="ml-auto mr-5 text-sm underline" on:click={() => ($swapFlashcards = true)}>
						Swap
					</button>
				{/if}
			</Dialog.Header>
			<Form {form}>
				<div slot="delete">
					<Dialog.Close asChild let:builder>
						<Button builders={[builder]} variant="destructive" class="w-full">Delete</Button>
					</Dialog.Close>
				</div>
				<div slot="update">
					<Dialog.Close asChild let:builder>
						<Button builders={[builder]} class="w-full">Update</Button>
					</Dialog.Close>
				</div>
				<div slot="add">
					<Dialog.Close asChild let:builder>
						<Button builders={[builder]} class="w-full">Add</Button>
					</Dialog.Close>
				</div>
			</Form>
		</Dialog.Content>
	</Dialog.Root>
{:else}
	<Drawer.Root {onClose} {open} {onOutsideClick}>
		<Drawer.Portal>
			<Drawer.Content class="max-h-fit">
				<Drawer.Header class="flex items-center text-left">
					<Drawer.Title class="w-full">
						{#if $clickedEditFlashcard}
							Edit {$clickedAddFlashcardCollection ? 'collection' : 'box'}
						{:else}
							Add a new {$clickedAddFlashcardCollection ? 'collection' : 'box'}
						{/if}
					</Drawer.Title>

					{#if !$clickedAddFlashcardCollection && $maxFlashcards !== '0' && $flashcardBoxes.length > 1}
						<Drawer.Nested>
							<Drawer.Trigger
								class="w-min items-center text-sm underline"
								on:click={() => ($swapFlashcards = true)}
							>
								Swap
							</Drawer.Trigger>
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
					{/if}
				</Drawer.Header>
				<Form {form}>
					<Button variant="destructive" slot="delete" class="w-full">Delete</Button>
					<Button slot="update" class="w-full">Update</Button>
					<Button slot="add" class="w-full">Add</Button>
				</Form>
				<Drawer.Footer class="h-fit">
					<Drawer.Close asChild let:builder>
						<Button builders={[builder]} variant="outline">Cancel</Button>
					</Drawer.Close>
				</Drawer.Footer>
			</Drawer.Content>
		</Drawer.Portal>
	</Drawer.Root>
{/if}
