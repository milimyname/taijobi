<script lang="ts">
	import Button from '$lib/components/ui/button/button.svelte';
	import * as DrawerDialog from '$lib/components/ui/drawer-dialog';
	import type { ConjugationFormSchema } from '$lib/utils/zodSchema';
	import type { Infer, SuperForm } from 'sveltekit-superforms';
	import { nestedSearchDrawerOpen, selectedConjugatingFlashcards } from '$lib/utils/stores';
	import { getContext } from 'svelte';
	import { ScrollArea } from '$lib/components/ui/scroll-area';
	import * as Card from '$lib/components/ui/card';
	import { CircleX } from 'lucide-svelte';
	import FormConjugationForm from './form-conjugation-form.svelte';
	import type { FlashcardType } from '$lib/utils/ambient';

	const { form: formData, errors }: SuperForm<Infer<ConjugationFormSchema>> =
		getContext('superConjugationForm');

	function removeFlashcardFromSelected(flashcard: FlashcardType) {
		$selectedConjugatingFlashcards = [
			...$selectedConjugatingFlashcards.filter((card) => card !== flashcard),
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

	let disabled = Object.keys($errors).length > 0;

	$: if ($formData.name === '') disabled = true;
	else if ($formData.settings.length === 0) disabled = true;
	else disabled = false;

	$: if ($selectedConjugatingFlashcards.length === 0) onCloseDrawer();

	$: if ($selectedConjugatingFlashcards) $formData.flashcards = $selectedConjugatingFlashcards;
</script>

<DrawerDialog.Root
	open={$nestedSearchDrawerOpen}
	onClose={onCloseDrawer}
	onOutsideClick={onClickOutSideClick}
>
	<DrawerDialog.Overlay class="fixed inset-0 z-[100] bg-black/10" />
	<DrawerDialog.Content class="drawerNested z-[101] w-full px-0 md:max-w-xl">
		<DrawerDialog.Header class="overflow-hidden px-0 text-left">
			<DrawerDialog.Title className="px-5">Add a new conjugation quiz</DrawerDialog.Title>
			<DrawerDialog.Description className="px-5">
				Select a collection and a box to add the selected flashcards to.
			</DrawerDialog.Description>
			<ScrollArea class="px-0" orientation="horizontal">
				<div class="flex space-x-4 pb-3 pl-5">
					{#each $selectedConjugatingFlashcards as flashcard}
						<Card.Root
							class="flex cursor-pointer flex-col justify-between transition-shadow duration-300 ease-linear hover:shadow-md"
						>
							<Card.Header class="relative">
								<Card.Title class="overflow-x-auto truncate">
									{flashcard?.name}
								</Card.Title>

								<Button
									size="icon"
									variant="none"
									class="absolute right-1.5 top-0.5 size-fit"
									on:click={() => removeFlashcardFromSelected(flashcard)}
								>
									<CircleX class="size-4 text-red-700" />
								</Button>
							</Card.Header>
						</Card.Root>
					{/each}
				</div>
			</ScrollArea>
		</DrawerDialog.Header>
		<FormConjugationForm {disabled}>
			<div slot="add">
				<DrawerDialog.Close asChild let:builder>
					<Button builders={[builder]} class="w-full" {disabled}>Add</Button>
				</DrawerDialog.Close>
			</div>
		</FormConjugationForm>
		<DrawerDialog.Footer className="md:hidden px-5">
			<DrawerDialog.Close asChild let:builder>
				<Button builders={[builder]} variant="outline">Cancel</Button>
			</DrawerDialog.Close>
		</DrawerDialog.Footer>
	</DrawerDialog.Content>
</DrawerDialog.Root>
