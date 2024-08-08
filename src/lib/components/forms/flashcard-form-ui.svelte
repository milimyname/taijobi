<script lang="ts">
	import {
		clickedEditFlashcard,
		clickedAddFlashcardCollection,
		clickedFeedback,
		deleteDrawerDialogOpen,
	} from '$lib/utils/stores';
	import { Button } from '$lib/components/ui/button';
	import * as Form from '$lib/components/ui/form';
	import { type FlashcardSchema } from '$lib/utils/zodSchema';
	import { type SuperForm, type Infer } from 'sveltekit-superforms';
	import FlashcardForm from '$lib/components/forms/flashcard-form.svelte';
	import { getContext } from 'svelte';
	import * as DrawerDialog from '$lib/components/ui/drawer-dialog';
	import DeleteDrawerAlertDialog from '$lib/components/drawer-alert-dialogs/delete-drawer-alert-dialog.svelte';
	import DeleteTrashButton from '$lib/components/delete-trash-button.svelte';
	import { cn } from '$lib/utils';

	let form: SuperForm<Infer<FlashcardSchema>> = getContext('flashcardForm');

	const { form: formData, delayed, isTainted, tainted, submit } = form;

	const onOutsideClick = () => {
		setTimeout(() => {
			$clickedAddFlashcardCollection = false;
			$clickedEditFlashcard = false;
			form.reset();
		}, 100);
	};

	$: if ($clickedFeedback) {
		$clickedAddFlashcardCollection = false;
		$clickedEditFlashcard = false;
	}

	function deleteFlashcard() {
		submit();
		$clickedAddFlashcardCollection = false;
		$clickedEditFlashcard = false;
		setTimeout(() => ($deleteDrawerDialogOpen = false), 150);
	}

	$: disabled = $formData.name === '' || $formData.type === '' || !isTainted($tainted);
</script>

<DeleteDrawerAlertDialog onClick={deleteFlashcard} />

<DrawerDialog.Root
	onClose={onOutsideClick}
	open={$clickedAddFlashcardCollection || $clickedEditFlashcard}
	{onOutsideClick}
>
	<DrawerDialog.Content
		className={cn(
			'max-sm:fixed max-sm:bottom-0 max-sm:left-0  right-0 flex max-sm:max-h-[96%] flex-col',
			$deleteDrawerDialogOpen && 'z-60',
		)}
	>
		<div class="flex w-full flex-col max-md:overflow-auto md:gap-4">
			<DrawerDialog.Header class="text-left">
				<DrawerDialog.Title className="flex justify-between items-center">
					{#if $clickedEditFlashcard}
						<span> Update flashcard </span>
						<DeleteTrashButton loading={$delayed} />
					{:else}
						Add a new flashcard
					{/if}
				</DrawerDialog.Title>
			</DrawerDialog.Header>

			<FlashcardForm>
				<div slot="update">
					<DrawerDialog.Close asChild let:builder>
						<Button builders={[builder]} class="w-full" {disabled} loading={$delayed}>
							Update
						</Button>
					</DrawerDialog.Close>
				</div>

				<div slot="add">
					<DrawerDialog.Close asChild let:builder>
						<Button builders={[builder]} class="w-full" {disabled} loading={$delayed}>Add</Button>
					</DrawerDialog.Close>
				</div>
			</FlashcardForm>

			<DrawerDialog.Footer className="md:hidden">
				<DrawerDialog.Close asChild let:builder>
					<Button builders={[builder]} variant="outline">Cancel</Button>
				</DrawerDialog.Close>
			</DrawerDialog.Footer>
		</div>
	</DrawerDialog.Content>
</DrawerDialog.Root>
