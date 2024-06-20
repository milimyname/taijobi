<script lang="ts">
	import { Badge } from '$lib/components/ui/badge/index';
	import { ArrowDown01, ArrowDown10, Settings } from 'lucide-svelte';
	import { Button } from '$lib/components/ui/button/index';
	import * as DrawerDialog from '$lib/components/ui/drawerDialog';
	import { goto } from '$app/navigation';
	import { VERB_CONJUGATION_TYPES } from '$lib/utils/constants';
	import Checkbox from '$lib/components/ui/checkbox/checkbox.svelte';
	import Label from '$lib/components/ui/label/label.svelte';
	import ConjugateDrawerDialog from './conjugate-drawer-dialog.svelte';
	import { openConjugation } from '$lib/utils/stores';

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

	$: if (showSettings) {
		const settings = localStorage.getItem(`conjugationSettings_${selectedConjugation?.id}`);
		if (settings) checkedList = JSON.parse(settings);
	}

	function onOutsideClickDrawer(e: MouseEvent | TouchEvent | PointerEvent) {
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
		selectedConjugation = conjugation;
	}

	$: conjugations = (() => {
		// Apply hiddenExamples filter
		return data.conjugationDemoList.filter(() => !hiddenExamples);
	})();
</script>

<ConjugateDrawerDialog flashcardBoxes={data?.ogFlashcardBoxes} />

<DrawerDialog.Root open={showSettings} onOutsideClick={onOutsideClickDrawer} {onClose}>
	<DrawerDialog.Content>
		<DrawerDialog.Header class="text-left">
			<DrawerDialog.Title>Change conjugation settings</DrawerDialog.Title>
		</DrawerDialog.Header>
		<div class="grid items-center gap-4 grid-cols-[repeat(2,1rem_1fr)] px-5 md:px-0">
			{#each Object.entries(VERB_CONJUGATION_TYPES) as [type, value]}
				<Checkbox
					id={type}
					checked={checkedList.includes(value)}
					on:click={() => {
						if (checkedList.includes(value))
							checkedList = checkedList.filter((item) => item !== value);
						else checkedList = [...checkedList, value];

						localStorage.setItem(
							`conjugationSettings_${selectedConjugation?.id}`,
							JSON.stringify(checkedList),
						);
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
	<div class="flex flex-wrap gap-2 items-center">
		<Button size="sm" variant="outline" on:click={() => (hiddenExamples = !hiddenExamples)}>
			{#if hiddenExamples}
				<span>Show examples</span>
			{:else}
				<span>Hide examples</span>
			{/if}
		</Button>
		<Button size="sm" variant="outline" on:click={() => (sortedByDate = !sortedByDate)}>
			{#if sortedByDate}
				<ArrowDown10 class="size-5 mr-2" />
			{:else}
				<ArrowDown01 class="size-5 mr-2" />
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
					<h4 class="text-xl font-medium truncate">
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
			</button>
		{/each}
	</div>
</section>
