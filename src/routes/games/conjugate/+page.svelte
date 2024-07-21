<script lang="ts">
	import { Badge } from '$lib/components/ui/badge/index';
	import { ArrowDown01, ArrowDown10, Settings } from 'lucide-svelte';
	import { Button } from '$lib/components/ui/button/index';
	import * as DrawerDialog from '$lib/components/ui/drawer-dialog';
	import { goto } from '$app/navigation';
	import { VERB_CONJUGATION_TYPES } from '$lib/utils/constants';
	import Checkbox from '$lib/components/ui/checkbox/checkbox.svelte';
	import Label from '$lib/components/ui/label/label.svelte';
	import ConjugateDrawerDialog from './conjugate-drawer-dialog.svelte';
	import {
		openConjugation,
		nestedSearchDrawerOpen,
		selectedConjugatingFlashcards,
		deleteHistoryOpen,
	} from '$lib/utils/stores';
	import { setContext } from 'svelte';
	import { toast } from 'svelte-sonner';
	import { zodClient } from 'sveltekit-superforms/adapters';
	import { superForm } from 'sveltekit-superforms';
	import { conjugationFormSchema } from '$lib/utils/zodSchema';
	import { pocketbase } from '$lib/utils/pocketbase';
	import DeleteDrawerAlertDialog from '$lib/components/drawer-alert-dialogs/delete-drawer-alert-dialog.svelte';
	import { cn } from '$lib/utils';
	import DeleteTrashButton from '$lib/components/delete-trash-button.svelte';
	import { ScrollArea } from '$lib/components/ui/scroll-area';
	import * as Card from '$lib/components/ui/card';

	export let data;

	type Conjugation = {
		id: string;
		name: string;
		type: string;
		data: string[];
	};

	let sortedByDate = false;
	let hiddenExamples = false;
	let showSettings = false;
	let checkedList: string[] = [];
	let selectedConjugation: Conjugation | null = null;

	// Search for Flashcard collection form:
	const superConjugationForm = superForm(data.form, {
		dataType: 'json',
		validators: zodClient(conjugationFormSchema),
		onUpdated: ({ form }) => {
			// Keep the form open if there is an error
			if (Object.keys(form.errors).length !== 0) return ($nestedSearchDrawerOpen = true);

			// Close the form if there is no error
			$nestedSearchDrawerOpen = false;
			$selectedConjugatingFlashcards = [];
			// Set it to the current flashcard collection
			// localStorage.setItem('currentFlashcardCollectionId', form.data.collectionId);
			toast('New Conjugation Quiz created successfully', {
				action: {
					label: 'See it now',
					onClick: () => {
						goto(`/games/conjugate/${form.data.id}`);
					},
				},
			});
		},
	});

	// Set Contexts
	setContext('ogFlashcardBoxes', data?.ogFlashcardBoxes);
	setContext('superConjugationForm', superConjugationForm);

	$: console.log(selectedConjugation);

	function onOutsideClickDrawer() {
		if ($deleteHistoryOpen) return;

		setTimeout(() => {
			showSettings = false;
		}, 100);
	}

	function onClose() {
		setTimeout(() => {
			showSettings = false;
		}, 100);
	}

	function onClickButton(e: MouseEvent | TouchEvent | PointerEvent, conjugation: Conjugation) {
		e.stopPropagation();
		showSettings = !showSettings;
		// Remove expand
		const { expand, ...rest } = {
			...conjugation,
			flashcards: conjugation?.expand?.flashcards || conjugation?.flashcards,
		};

		selectedConjugation = rest;

		checkedList = selectedConjugation?.settings || [];
	}

	async function handleDelete(id: string) {
		try {
			await pocketbase.collection('conjugations').delete(id);

			// filter out the deleted conjugation
			data.conjugations = data.conjugations.filter((conjugation) => conjugation.id !== id);
			// close the settings drawer
			showSettings = false;
		} catch (error) {
			console.error(error);
		}

		setTimeout(() => ($deleteHistoryOpen = false), 150);
	}

	$: if (showSettings) {
		const settings = localStorage.getItem(`conjugationSettings_${selectedConjugation?.id}`);
		if (settings) checkedList = JSON.parse(settings);
	}

	$: conjugations = (() => {
		// Apply hiddenExamples filter
		const updatedConjugations = [
			...data.conjugationDemoList.filter(() => !hiddenExamples),
			...data.conjugations,
		];

		return sortedByDate
			? updatedConjugations.sort(
					(a, b) => Number(new Date(b.created)) - Number(new Date(a.created)),
				)
			: updatedConjugations.sort(
					(a, b) => Number(new Date(a.created)) - Number(new Date(b.created)),
				);
	})();
</script>

<ConjugateDrawerDialog />

<DeleteDrawerAlertDialog onClick={() => handleDelete(selectedConjugation?.id)} />

<DrawerDialog.Root open={showSettings} onOutsideClick={onOutsideClickDrawer} {onClose}>
	<DrawerDialog.Content
		className={cn('px-0', $deleteHistoryOpen && selectedConjugation?.id !== 'demo' && 'z-60')}
	>
		<DrawerDialog.Header class="overflow-hidden px-0 text-left">
			<DrawerDialog.Title className="flex px-5 justify-between items-center">
				<span>Change conjugation settings</span>

				{#if selectedConjugation?.id !== 'demo'}
					<DeleteTrashButton />
				{/if}
			</DrawerDialog.Title>
		</DrawerDialog.Header>

		<ScrollArea class="px-0" orientation="horizontal">
			<div class={'flex space-x-4 pb-3 pl-5'}>
				{#each selectedConjugation?.flashcards as flashcard}
					<Card.Root
						class="flex cursor-pointer flex-col justify-between transition-shadow duration-300 ease-linear hover:shadow-md"
					>
						<Card.Header class="relative">
							<Card.Title class="overflow-x-auto truncate">
								{flashcard?.name}
							</Card.Title>
						</Card.Header>
					</Card.Root>
				{/each}
			</div>
		</ScrollArea>

		<div class="grid grid-cols-[repeat(2,1rem_1fr)] items-center gap-4 px-5">
			{#each Object.entries(VERB_CONJUGATION_TYPES) as [type, value]}
				<Checkbox
					id={type}
					checked={checkedList.includes(value)}
					on:click={async () => {
						if (checkedList.includes(value))
							checkedList = checkedList.filter((item) => item !== value);
						else checkedList = [...checkedList, value];

						if (selectedConjugation?.id === 'demo') {
							localStorage.setItem(
								`conjugationSettings_${selectedConjugation?.id}`,
								JSON.stringify(checkedList),
							);
						} else {
							try {
								await pocketbase.collection('conjugations').update(selectedConjugation?.id, {
									settings: checkedList,
								});
							} catch (error) {
								console.error(error);
							}
						}
					}}
				/>
				<Label for={type}>{value}</Label>
			{/each}
		</div>

		<DrawerDialog.Footer className="md:hidden">
			<DrawerDialog.Close asChild let:builder>
				<Button builders={[builder]} variant="outline">Cancel</Button>
			</DrawerDialog.Close>
		</DrawerDialog.Footer>
	</DrawerDialog.Content>
</DrawerDialog.Root>

<section class="flex w-full max-w-4xl flex-col justify-center gap-5 overflow-y-scroll">
	<div class="flex flex-wrap items-center gap-2">
		<Button size="sm" variant="outline" on:click={() => (hiddenExamples = !hiddenExamples)}>
			{#if hiddenExamples}
				<span>Show examples</span>
			{:else}
				<span>Hide examples</span>
			{/if}
		</Button>
		<Button size="sm" variant="outline" on:click={() => (sortedByDate = !sortedByDate)}>
			{#if sortedByDate}
				<ArrowDown10 class="mr-2 size-5" />
			{:else}
				<ArrowDown01 class="mr-2 size-5" />
			{/if} <span>Sorted by date</span>
		</Button>
		<Button size="sm" on:click={() => ($openConjugation = true)}>Create</Button>
	</div>
	<div class="grid grid-flow-row gap-4 md:grid-cols-3">
		{#each conjugations as conjugation}
			<button
				class="flex w-full flex-col justify-center gap-4 rounded-lg border p-4"
				on:click={() => goto(`/games/conjugate/${conjugation.id}`)}
			>
				<div class="flex w-full justify-between">
					<h4 class="truncate text-xl font-medium">
						{conjugation.name}
					</h4>

					<div class="flex items-center gap-2">
						<Badge variant="outline">
							{conjugation.type}
						</Badge>
						<Button
							size="icon"
							variant="none"
							class="size-5"
							on:click={(e) => onClickButton(e, conjugation)}
						>
							<Settings />
						</Button>
					</div>
				</div>
				<div class="flex w-full justify-between">
					<div class="flex items-center gap-2">
						<Badge variant="outline">
							{new Date(conjugation.created).toLocaleDateString()}
						</Badge>
					</div>
				</div>
			</button>
		{/each}
	</div>
</section>
