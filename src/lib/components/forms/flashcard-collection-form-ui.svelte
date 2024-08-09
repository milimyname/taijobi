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
		currentBoxId,
		deleteDrawerDialogOpen,
		flashcardsBoxType,
		disabledSubmitCollection,
	} from '$lib/utils/stores';
	import QuizItems from './quiz-items.svelte';
	import { Button } from '$lib/components/ui/button';
	import { cn } from '$lib/utils';
	import { page } from '$app/stores';
	import { type FlashcardCollectionSchema } from '$lib/utils/zodSchema';
	import { type SuperForm, type Infer } from 'sveltekit-superforms';
	import FlashcardCollectionForm from '$lib/components/forms/flashcard-collection-form.svelte';
	import * as DrawerDialog from '$lib/components/ui/drawer-dialog';
	import DeleteDrawerAlertDialog from '$lib/components/drawer-alert-dialogs/delete-drawer-alert-dialog.svelte';
	import DeleteTrashButton from '$lib/components/delete-trash-button.svelte';
	import { getContext } from 'svelte';

	export let form: SuperForm<Infer<FlashcardCollectionSchema>>;

	let boxForm: SuperForm<Infer<FlashcardCollectionSchema>> = getContext('boxForm');

	const { form: formData, delayed, isTainted, tainted, submit, reset } = form;

	function onOutsideClick(e: PointerEvent | MouseEvent | TouchEvent) {
		// let eventTarget: Element | null = null;

		// if (e && 'changedTouches' in e && e.changedTouches.length > 0) {
		// 	// It's a TouchEvent
		// 	eventTarget = e.changedTouches[0].target as Element;
		// } else if (e && 'target' in e) {
		// 	// It's a MouseEvent or PointerEvent
		// 	eventTarget = e.target as Element;
		// }

		// Ensure eventTarget is not null before proceeding
		// if (!eventTarget) {
		// 	$clickedAddFlashcardCollection = false;
		// 	$clickedAddFlahcardBox = false;
		// 	$clickedEditFlashcard = false;
		// 	$selectedQuizItems = [];

		// 	return;
		// }

		// If the user clicks on the leave button, don't move the card
		// if (
		// 	($page.url.pathname.includes('flashcards') && eventTarget.closest('.add-btn')) ||
		// 	eventTarget.closest('.swap-items') ||
		// 	eventTarget.closest('.edit-collection-btn')
		// )
		// 	return;
		//
		// if ($deleteDrawerDialogOpen) return;

		setTimeout(() => {
			$clickedAddFlashcardCollection = false;
			$clickedAddFlahcardBox = false;
			$clickedEditFlashcard = false;
			$selectedQuizItems = [];
			reset();
		}, 100);
	}

	function deleteCollectionOrBox() {
		if ($clickedAddFlashcardCollection) submit();

		if ($clickedAddFlahcardBox) boxForm.submit();

		// Clear currentFlashcardCollectionId from localStorage
		localStorage.removeItem('currentFlashcardCollectionId');

		setTimeout(() => {
			$deleteDrawerDialogOpen = false;
			$clickedAddFlashcardCollection = false;
			$clickedEditFlashcard = false;
			$clickedAddFlahcardBox = false;
		}, 150);
	}

	$: open = $clickedAddFlashcardCollection || $clickedAddFlahcardBox;

	$: if ($clickedFeedback) {
		$clickedAddFlashcardCollection = false;
		$clickedAddFlahcardBox = false;
		$clickedEditFlashcard = false;
	}

	$: isSwappable =
		(!$clickedAddFlashcardCollection &&
			$maxFlashcards !== '0' &&
			$flashcardBoxes.length > 1 &&
			$flashcardsBoxType !== 'original') ||
		($page.data.isAdmin && !$clickedAddFlashcardCollection);

	$: $disabledSubmitCollection = $formData.name === '' || !isTainted($tainted);
</script>

<DeleteDrawerAlertDialog onClick={deleteCollectionOrBox} />

<DrawerDialog.Root bind:open={$swapFlashcards}>
	<DrawerDialog.Content class="swap-items z-[101] max-w-2xl p-0">
		<QuizItems flashcardBox={$currentBoxId}>
			<DrawerDialog.Close asChild let:builder>
				<Button
					builders={[builder]}
					on:click={() => {
						$selectQuizItemsForm = false;
						$swapFlashcards = false;
						$selectedQuizItems = [];
					}}
					variant="outline"
					class="max-md:hidden"
				>
					Cancel
				</Button>
			</DrawerDialog.Close>
		</QuizItems>

		<DrawerDialog.Footer className="md:hidden">
			<DrawerDialog.Close asChild let:builder>
				<Button builders={[builder]} variant="outline">Cancel</Button>
			</DrawerDialog.Close>
		</DrawerDialog.Footer>
	</DrawerDialog.Content>
</DrawerDialog.Root>

<DrawerDialog.Root onClose={onOutsideClick} bind:open {onOutsideClick}>
	<DrawerDialog.Content
		className={cn(
			'right-0 max-md:h-full flex flex-col max-md:fixed max-md:bottom-0 max-md:left-0 max-md:max-h-[90dvh]',
			$deleteDrawerDialogOpen && 'z-60',
		)}
	>
		<div class="flex w-full flex-col max-md:overflow-auto md:gap-4">
			<DrawerDialog.Header class="text-left">
				<DrawerDialog.Title className="flex justify-between items-center">
					{#if $clickedEditFlashcard}
						<span>Edit {$clickedAddFlashcardCollection ? 'collection' : 'box'}</span>
						{#if ($page.data.isAdmin || $flashcardsBoxType !== 'original') && $clickedEditFlashcard}
							<div class="flex gap-2">
								{#if isSwappable}
									<Button variant="link" on:click={() => ($swapFlashcards = true)}>Swap</Button>
								{/if}
								<DeleteTrashButton loading={$delayed} />
							</div>
						{/if}
					{:else}
						Add a new {$clickedAddFlashcardCollection ? 'collection' : 'box'}
					{/if}
				</DrawerDialog.Title>
			</DrawerDialog.Header>
			<FlashcardCollectionForm {form}>
				<div slot="update">
					<DrawerDialog.Close asChild let:builder>
						<Button
							builders={[builder]}
							class="w-full"
							disabled={$disabledSubmitCollection}
							loading={$delayed}
						>
							Update
						</Button>
					</DrawerDialog.Close>
				</div>

				<div slot="add">
					<DrawerDialog.Close asChild let:builder>
						<Button
							builders={[builder]}
							class="w-full"
							disabled={$disabledSubmitCollection}
							loading={$delayed}
						>
							Add
						</Button>
					</DrawerDialog.Close>
				</div>
			</FlashcardCollectionForm>

			<DrawerDialog.Footer className="md:hidden">
				<DrawerDialog.Close asChild let:builder>
					<Button builders={[builder]} variant="outline">Cancel</Button>
				</DrawerDialog.Close>
			</DrawerDialog.Footer>
		</div>
	</DrawerDialog.Content>
</DrawerDialog.Root>
