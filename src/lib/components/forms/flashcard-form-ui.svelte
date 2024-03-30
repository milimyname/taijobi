<script lang="ts">
	import {
		clickedEditFlashcard,
		clickedAddFlashcardCollection,
		clickedFeedback
	} from '$lib/utils/stores';
	import * as Dialog from '$lib/components/ui/dialog';
	import * as Drawer from '$lib/components/ui/drawer';
	import { Button } from '$lib/components/ui/button';
	import { isDesktop, cn } from '$lib/utils';
	import * as Form from '$lib/components/ui/form';
	import { type FlashcardSchema } from '$lib/utils/zodSchema';
	import { type SuperForm, type Infer } from 'sveltekit-superforms';
	import FlashcardForm from '$lib/components/forms/flashcard-form.svelte';

	export let form: SuperForm<Infer<FlashcardSchema>>;

	const { form: formData } = form;

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

	$: disabled = $formData.name === '' || $formData.type === '';
</script>

{#if $isDesktop}
	<Dialog.Root bind:open {onOutsideClick}>
		<Dialog.Content class="z-[100] sm:max-w-[425px]">
			<Dialog.Header>
				<Dialog.Title>
					{#if $clickedEditFlashcard}
						Update flashcard
					{:else}
						Add a new flashcard
					{/if}
				</Dialog.Title>
			</Dialog.Header>
			<FlashcardForm {form}>
				<div slot="delete">
					<Form.Button formaction="?/delete" variant="destructive" class="w-full">
						Delete
					</Form.Button>
				</div>
				<div slot="update">
					<Form.Button formaction="?/update" class="w-full">Update</Form.Button>
				</div>
				<div slot="add">
					<Form.Button formaction="?/add" class="w-full">Add</Form.Button>
				</div>
			</FlashcardForm>
		</Dialog.Content>
	</Dialog.Root>
{:else}
	<Drawer.Root onClose={onOutsideClick} {open} {onOutsideClick}>
		<Drawer.Portal>
			<Drawer.Content class="fixed bottom-0 left-0 right-0 max-h-[96%]">
				<div class="flex w-full flex-col overflow-auto">
					<Drawer.Header class="text-left">
						<Drawer.Title>
							{#if $clickedEditFlashcard}
								Update flashcard
							{:else}
								Add a new flashcard
							{/if}
						</Drawer.Title>
					</Drawer.Header>

					<FlashcardForm {form}>
						<div slot="delete">
							<Drawer.Close asChild let:builder>
								<Form.Button builders={[builder]} variant="destructive" class="w-full">
									Delete
								</Form.Button>
							</Drawer.Close>
						</div>

						<div slot="update">
							<Drawer.Close asChild let:builder>
								<Form.Button builders={[builder]} class="w-full" {disabled}>Update</Form.Button>
							</Drawer.Close>
						</div>
						<div slot="add">
							<Drawer.Close asChild let:builder>
								<Form.Button builders={[builder]} class="w-full" {disabled}>Add</Form.Button>
							</Drawer.Close>
						</div>
					</FlashcardForm>

					<Drawer.Footer>
						<Drawer.Close asChild let:builder>
							<Button builders={[builder]} variant="outline">Cancel</Button>
						</Drawer.Close>
					</Drawer.Footer>
				</div>
			</Drawer.Content>
		</Drawer.Portal>
	</Drawer.Root>
{/if}
