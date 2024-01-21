<script lang="ts">
	import {
		clickedEditFlashcard,
		clickedAddFlashcardCollection,
		clickedFeedback
	} from '$lib/utils/stores';
	import * as Dialog from '$lib/components/ui/dialog';
	import * as Drawer from '$lib/components/ui/drawer';
	import { Button } from '$lib/components/ui/button';
	import Form from '$lib/components/forms/flashcard-form.svelte';
	import { isDesktop } from '$lib/utils';
	import type { SuperForm } from 'sveltekit-superforms/client';
	import type { ZodValidation, SuperValidated } from 'sveltekit-superforms';
	import type { AnyZodObject } from 'zod';
	import type { Writable } from 'svelte/store';

	export let form: Writable<SuperValidated<any, any>['data']>;
	export let errors: Writable<SuperValidated<any, any>['errors']> & {
		clear: () => void;
	};
	export let constraints: any; // Replace 'any' with the appropriate type
	export let enhance: SuperForm<ZodValidation<AnyZodObject>>['enhance'] = (el, events) => ({
		destroy() {}
	});

	function onOutsideClick() {
		$clickedAddFlashcardCollection = false;
	}

	$: if ($clickedFeedback) {
		$clickedAddFlashcardCollection = false;
		$clickedEditFlashcard = false;
	}
</script>

{#if $isDesktop}
	<Dialog.Root bind:open={$clickedAddFlashcardCollection} {onOutsideClick}>
		<Dialog.Content class=" sm:max-w-[425px]">
			<Dialog.Header>
				<Dialog.Title>
					{#if $clickedEditFlashcard}
						Update flashcard
					{:else}
						Add a new flashcard
					{/if}
				</Dialog.Title>
			</Dialog.Header>
			<Form {enhance} {errors} {form} {constraints}>
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
					<Button class="w-full">Add</Button>
				</div>
			</Form>
		</Dialog.Content>
	</Dialog.Root>
{:else}
	<Drawer.Root
		onClose={() => {
			$clickedAddFlashcardCollection = false;
			$clickedEditFlashcard = false;
		}}
		open={$clickedAddFlashcardCollection}
		shouldScaleBackground
	>
		<Drawer.Portal>
			<Drawer.Content>
				<Drawer.Header class="text-left">
					<Drawer.Title>
						{#if $clickedEditFlashcard}
							Update flashcard
						{:else}
							Add a new flashcard
						{/if}
					</Drawer.Title>
				</Drawer.Header>
				<Form {enhance} {errors} {form} {constraints}>
					<Button variant="destructive" slot="delete" class="w-full">Delete</Button>
					<Button slot="update" class="w-full">Update</Button>
					<Button slot="add" class="w-full">Add</Button>
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
