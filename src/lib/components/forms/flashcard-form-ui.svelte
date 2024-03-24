<script lang="ts">
	import {
		clickedEditFlashcard,
		clickedAddFlashcardCollection,
		clickedFeedback
	} from '$lib/utils/stores';
	import * as Dialog from '$lib/components/ui/dialog';
	import * as Drawer from '$lib/components/ui/drawer';
	import { Button } from '$lib/components/ui/button';
	import FlashcardForm from '$lib/components/forms/flashcard-form.svelte';
	import { isDesktop } from '$lib/utils';
	import { type FlashcardSchema } from '$lib/utils/zodSchema';
	import { type SuperForm } from 'sveltekit-superforms/client';

	export let form: SuperForm<FlashcardSchema>;

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
</script>

{#if $isDesktop}
	<Dialog.Root bind:open={$clickedAddFlashcardCollection} {onOutsideClick}>
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
			</FlashcardForm>
		</Dialog.Content>
	</Dialog.Root>
{:else}
	<Drawer.Root onClose={onOutsideClick} open={$clickedAddFlashcardCollection} {onOutsideClick}>
		<Drawer.Portal>
			<Drawer.Content class="fixed bottom-0 left-0 right-0 max-h-[96%]">
				<div class="flex w-full flex-col overflow-auto rounded-t-[10px]">
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
						<Button variant="destructive" slot="delete" class="w-full">Delete</Button>
						<Button slot="update" class="w-full">Update</Button>
						<Button slot="add" class="w-full">Add</Button>
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
