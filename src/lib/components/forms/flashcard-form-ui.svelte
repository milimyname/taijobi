<script lang="ts">
	import {
		clickedEditFlashcard,
		clickedAddFlashcardCollection,
		clickedFeedback,
	} from '$lib/utils/stores';
	import { Button } from '$lib/components/ui/button';
	import * as Form from '$lib/components/ui/form';
	import { type FlashcardSchema } from '$lib/utils/zodSchema';
	import { type SuperForm, type Infer } from 'sveltekit-superforms';
	import FlashcardForm from '$lib/components/forms/flashcard-form.svelte';
	import { getContext } from 'svelte';
	import * as DrawerDialog from '$lib/components/ui/drawerDialog';

	let form: SuperForm<Infer<FlashcardSchema>> = getContext('flashcardForm');

	const { form: formData, delayed, isTainted, tainted } = form;

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

	$: open = $clickedAddFlashcardCollection || $clickedEditFlashcard;

	$: disabled = $formData.name === '' || $formData.type === '' || !isTainted($tainted);
</script>

<DrawerDialog.Root onClose={onOutsideClick} {open} {onOutsideClick}>
	<DrawerDialog.Content scrollable>
		<DrawerDialog.Header class="text-left">
			<DrawerDialog.Title>
				{#if $clickedEditFlashcard}
					Update flashcard
				{:else}
					Add a new flashcard
				{/if}
			</DrawerDialog.Title>
		</DrawerDialog.Header>

		<FlashcardForm {disabled}>
			<div slot="delete">
				<DrawerDialog.Close asChild let:builder>
					<Form.Button builders={[builder]} variant="destructive" class="w-full">
						Delete
					</Form.Button>
				</DrawerDialog.Close>
			</div>

			<div slot="update">
				<DrawerDialog.Close asChild let:builder>
					<Form.Button builders={[builder]} class="w-full" {disabled} loading={$delayed}>
						Update
					</Form.Button>
				</DrawerDialog.Close>
			</div>
			<div slot="add">
				<DrawerDialog.Close asChild let:builder>
					<Form.Button builders={[builder]} class="w-full" {disabled} loading={$delayed}>
						Add
					</Form.Button>
				</DrawerDialog.Close>
			</div>
		</FlashcardForm>

		<DrawerDialog.Footer className="md:hidden">
			<DrawerDialog.Close asChild let:builder>
				<Button builders={[builder]} variant="outline">Cancel</Button>
			</DrawerDialog.Close>
		</DrawerDialog.Footer>
	</DrawerDialog.Content>
</DrawerDialog.Root>
