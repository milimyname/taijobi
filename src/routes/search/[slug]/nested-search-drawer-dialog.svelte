<script lang="ts">
	import Button from '$lib/components/ui/button/button.svelte';
	import * as DrawerDialog from '$lib/components/ui/drawer-dialog';
	import { quintOut } from 'svelte/easing';
	import { slide } from 'svelte/transition';
	import FormSearchDrawerDialog from './form-search-drawer-dialog.svelte';
	import type { SearchCollectionSchema } from '$lib/utils/zodSchema';
	import type { Infer, SuperForm } from 'sveltekit-superforms';
	import { nestedSearchDrawerOpen, selectedSearchFlashcards } from '$lib/utils/stores';
	import { getContext } from 'svelte';
	import type { RecordModel } from 'pocketbase';
	import { ScrollArea } from '$lib/components/ui/scroll-area';
	import * as Card from '$lib/components/ui/card';
	import { CircleX } from 'lucide-svelte';

	let form: SuperForm<Infer<SearchCollectionSchema>> = getContext('flashcardCollectionForm');

	function openNestedSearchDrawer() {
		$nestedSearchDrawerOpen = true;
	}

	function removeFlashcardFromSelected(box: RecordModel) {
		$selectedSearchFlashcards = [
			...$selectedSearchFlashcards.filter((selectedBox) => selectedBox.id !== box.id),
		];
	}

	function onCloseDrawer() {
		setTimeout(() => ($nestedSearchDrawerOpen = false), 100);
	}

	function onClickOutSideClick(e: PointerEvent | MouseEvent | TouchEvent) {
		let eventTarget = (
			(e as TouchEvent).changedTouches ? (e as TouchEvent).changedTouches[0].target : e.target
		) as Element;

		// If the user clicks on the leave button, don't move the card
		if (eventTarget.closest('.drawerNested')) return;

		onCloseDrawer();
	}

	const { form: formData, errors } = form;

	let disabled = Object.keys($errors).length > 0;

	$: if ($formData.collectionId === '' || $formData.boxId === '') disabled = true;
	else if (
		$formData.collectionId !== 'new-collection' &&
		$formData.boxId === 'new-box' &&
		$formData.boxName !== ''
	)
		disabled = false;
	else if (
		($formData.collectionId === 'new-collection' || $formData.boxId === 'new-box') &&
		($formData.collectionName === '' || $formData.boxName === '')
	)
		disabled = true;
	else disabled = false;

	$: if ($selectedSearchFlashcards)
		$formData.flashcards = $selectedSearchFlashcards.map((box) => {
			return {
				id: box?.expand?.flashcard?.id,
				name: box?.expand?.flashcard?.name,
				meaning: box?.expand?.flashcard?.meaning,
				furigana: box?.expand?.flashcard?.furigana,
				romaji: box?.expand?.flashcard?.romaji,
				partOfSpeech: box?.expand?.flashcard?.partOfSpeech,
				type: box?.expand?.flashcard?.type,
			};
		});

	$: if ($selectedSearchFlashcards.length === 0) onCloseDrawer();
</script>

<DrawerDialog.Root
	open={$nestedSearchDrawerOpen}
	onClose={onCloseDrawer}
	onOutsideClick={onClickOutSideClick}
>
	<div transition:slide={{ duration: 300, easing: quintOut, axis: 'y' }} class="w-full">
		<DrawerDialog.Trigger asChild>
			<Button class="w-full" on:click={openNestedSearchDrawer}>Create Flashcard Box</Button>
		</DrawerDialog.Trigger>
	</div>

	<DrawerDialog.Content class="drawerNested z-[101] w-full px-0 md:max-w-xl">
		<DrawerDialog.Header class="overflow-hidden px-0 text-left">
			<DrawerDialog.Title className="px-5">Add a new flashcards box</DrawerDialog.Title>
			<DrawerDialog.Description className="px-5">
				Select a collection and a box to add the selected flashcards to.
			</DrawerDialog.Description>
			<ScrollArea class="px-0" orientation="horizontal">
				<div class="flex space-x-4 pb-3 pl-5">
					{#each $selectedSearchFlashcards as box}
						<Card.Root
							class="flex cursor-pointer flex-col justify-between transition-shadow duration-300 ease-linear hover:shadow-md"
						>
							<Card.Header class="relative">
								<Card.Title class="overflow-x-auto truncate">
									{box?.expand?.flashcard?.name}
								</Card.Title>

								<Button
									size="icon"
									variant="none"
									class="absolute right-1.5 top-0.5 size-fit"
									on:click={() => removeFlashcardFromSelected(box)}
								>
									<CircleX class="size-4 text-red-700" />
								</Button>
							</Card.Header>
						</Card.Root>
					{/each}
				</div>
			</ScrollArea>
		</DrawerDialog.Header>
		<FormSearchDrawerDialog>
			<div slot="add">
				<DrawerDialog.Close asChild let:builder>
					<Button builders={[builder]} class="w-full" {disabled}>Add</Button>
				</DrawerDialog.Close>
			</div>
		</FormSearchDrawerDialog>
		<DrawerDialog.Footer className="md:hidden px-5">
			<DrawerDialog.Close asChild let:builder>
				<Button builders={[builder]} variant="outline">Cancel</Button>
			</DrawerDialog.Close>
		</DrawerDialog.Footer>
	</DrawerDialog.Content>
</DrawerDialog.Root>
