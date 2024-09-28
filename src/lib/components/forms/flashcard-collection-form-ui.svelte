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
	import { cn, isDesktop } from '$lib/utils';
	import { page } from '$app/stores';
	import { type FlashcardCollectionSchema } from '$lib/utils/zodSchema';
	import { type SuperForm, type Infer } from 'sveltekit-superforms';
	import FlashcardCollectionForm from '$lib/components/forms/flashcard-collection-form.svelte';
	import * as DrawerDialog from '$lib/components/ui/drawer-dialog';
	import DeleteDrawerAlertDialog from '$lib/components/drawer-alert-dialogs/delete-drawer-alert-dialog.svelte';
	import DeleteTrashButton from '$lib/components/delete-trash-button.svelte';
	import { getContext } from 'svelte';
	import { pocketbase } from '$lib/utils/pocketbase';

	export let form: SuperForm<Infer<FlashcardCollectionSchema>>;

	let boxForm: SuperForm<Infer<FlashcardCollectionSchema>> = getContext('boxForm');

	const { form: formData, delayed, isTainted, tainted, submit, reset } = form;

	let selectedBoxId = $flashcardBoxes[0]?.id;

	function onOutsideClick() {
		if ($swapFlashcards) return;

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

	async function onSwapFlashcards() {
		// Swap the flashcards

		$selectedQuizItems.forEach(async (item) => {
			const [id] = item.split('=');
			await pocketbase.collection('flashcard').update(id, {
				flashcardBox: selectedBoxId,
			});
		});

		// Close the form
		$swapFlashcards = false;
		$selectQuizItemsForm = false;
		$clickedAddFlahcardBox = false;
		$clickedEditFlashcard = false;
		$selectedQuizItems = [];
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
		($page.data.isAdmin &&
			!$clickedAddFlashcardCollection &&
			$maxFlashcards !== '0' &&
			$flashcardBoxes.length > 1);

	$: $disabledSubmitCollection = $formData.name === '' || !isTainted($tainted);
</script>

<DeleteDrawerAlertDialog
	onClick={deleteCollectionOrBox}
	description="This action cannot be undone. This will permanently delete your collection."
/>
/>

<DrawerDialog.Root bind:open={$swapFlashcards}>
	<DrawerDialog.Overlay class="fixed inset-0 z-[100] bg-black/10" />
	<DrawerDialog.Content class="swap-items z-[101] max-w-2xl px-5">
		<DrawerDialog.Header className="max-md:px-0">
			<DrawerDialog.Title>Swap flashcards</DrawerDialog.Title>
		</DrawerDialog.Header>
		<QuizItems flashcardBox={$currentBoxId}>
			<DrawerDialog.Footer className="md:grid grid-cols-2 gap-10 max-md:px-0">
				<div class="col-span-full self-center">
					<span>Move to</span>
					<select
						bind:value={selectedBoxId}
						class="border-hidden bg-none pr-3 text-center font-bold outline-none focus:border-transparent focus:ring-0"
					>
						{#each $flashcardBoxes as box}
							{#if box.id !== $currentBoxId}
								<option value={box.id}>{box.name}</option>
							{/if}
						{/each}
					</select>
					<span>box</span>
				</div>

				<div class="col-span-full flex flex-col-reverse gap-2 md:flex-row">
					<DrawerDialog.Close asChild let:builder>
						<Button
							builders={[builder]}
							on:click={() => {
								$selectQuizItemsForm = false;
								$swapFlashcards = false;
								$selectedQuizItems = [];
								$clickedAddFlahcardBox = true;
							}}
							variant="outline"
							class="w-full"
						>
							Cancel
						</Button>
					</DrawerDialog.Close>

					<DrawerDialog.Close asChild let:builder>
						<Button builders={[builder]} on:click={onSwapFlashcards} class="w-full">Save</Button>
					</DrawerDialog.Close>
				</div>
			</DrawerDialog.Footer>
		</QuizItems>
	</DrawerDialog.Content>
</DrawerDialog.Root>

<DrawerDialog.Root onClose={onOutsideClick} bind:open {onOutsideClick}>
	<DrawerDialog.Content
		className={cn(
			'right-0 max-md:h-full flex flex-col max-md:fixed max-md:bottom-0 max-md:left-0 max-md:max-h-[90dvh]',
			$deleteDrawerDialogOpen && 'z-60',
		)}
	>
		<div
			class={cn(
				'flex w-full flex-col max-md:h-full max-md:overflow-auto',
				$clickedEditFlashcard && !$clickedAddFlashcardCollection && !$isDesktop && 'z-60',
			)}
		>
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
				<div
					slot="update"
					class={cn(
						'space-y-2',
						$clickedEditFlashcard && !$clickedAddFlashcardCollection && !$isDesktop && 'pb-40',
					)}
				>
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
					<DrawerDialog.Footer className="md:hidden p-0">
						<DrawerDialog.Close asChild let:builder>
							<Button
								builders={[builder]}
								variant="outline"
								on:click={(e) => {
									e.preventDefault();
									onOutsideClick();
								}}
							>
								Cancel
							</Button>
						</DrawerDialog.Close>
					</DrawerDialog.Footer>
				</div>

				<div
					slot="add"
					class={cn(
						'space-y-2',
						$clickedEditFlashcard && !$clickedAddFlashcardCollection && !$isDesktop && 'pb-40',
					)}
				>
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
					<DrawerDialog.Footer className="p-0">
						<DrawerDialog.Close asChild let:builder>
							<Button
								builders={[builder]}
								variant="outline"
								on:click={(e) => {
									e.preventDefault();
									onOutsideClick();
								}}
							>
								Cancel
							</Button>
						</DrawerDialog.Close>
					</DrawerDialog.Footer>
				</div>
			</FlashcardCollectionForm>
		</div>
	</DrawerDialog.Content>
</DrawerDialog.Root>
