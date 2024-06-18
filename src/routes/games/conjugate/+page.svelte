<script lang="ts">
	import { pocketbase } from '$lib/utils/pocketbase';
	import { Badge } from '$lib/components/ui/badge/index';
	import { ArrowDownUp, Settings } from 'lucide-svelte';
	import { Button } from '$lib/components/ui/button/index';
	import type { RecordModel } from 'pocketbase';
	import * as DrawerDialog from '$lib/components/ui/drawerDialog';
	import { goto } from '$app/navigation';
	import { VERB_CONJUGATION_TYPES } from '$lib/utils/constants';
	import Checkbox from '$lib/components/ui/checkbox/checkbox.svelte';
	import Label from '$lib/components/ui/label/label.svelte';

	export let data;

	let sortedByDate = false;
	let hiddenExamples = false;
	let showSettings = false;
	let checkedList: string[] = [];
	let selectedConjugation: RecordModel | null = null;

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

	$: conjugations = (() => {
		// Apply hiddenExamples filter
		// let filteredList = data.conjugationDemoList.filter(() => !hiddenExamples);
		return data.conjugationDemoList.filter(() => !hiddenExamples);

		// Then, sort the filtered quizzes based on sortedByDate
		// return sortedByDate
		// 	? filteredList.sort(
		// 			(a: RecordModel, b: RecordModel) =>
		// 				Number(new Date(b.created)) - Number(new Date(a.created)),
		// 		)
		// 	: filteredList.sort(
		// 			(a: RecordModel, b: RecordModel) =>
		// 				Number(new Date(a.created)) - Number(new Date(b.created)),
		// 		);
	})();
</script>

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
			<ArrowDownUp class="mr-2 size-4" />
			<span>Sorted by date</span>
		</Button>
		<Button size="sm">Create</Button>
	</div>
	<div class="grid grid-flow-row gap-4 md:grid-cols-3">
		{#each conjugations as conjugation}
			<button
				class="flex w-full flex-col justify-center gap-4 rounded-lg border p-4"
				on:click={() => goto(`/games/conjugate/${conjugation.id}`)}
			>
				<div class="flex w-full justify-between">
					<h4 class="text-xl font-medium truncate">
						Quiz: Quiz: Quiz: Quiz: Quiz: Quiz: Quiz: {conjugation.name}
					</h4>

					<div class="flex items-center gap-2">
						<Badge variant="outline">
							{conjugation.type}
						</Badge>
						<Button
							size="icon"
							variant="none"
							class="size-5"
							on:click={(e) => {
								e.stopPropagation();
								showSettings = !showSettings;
								selectedConjugation = conjugation;
							}}
						>
							<Settings />
						</Button>
					</div>
				</div>

				<div class="flex justify-between">
					<!-- <button
						class="self-center rounded-full font-bold"
						on:click={() => {
							localStorage.removeItem(`flashcards_${quiz.id}`);
							localStorage.removeItem(`currentQuestion_${quiz.id}`);
							localStorage.removeItem(`quizProgress_${quiz.id}`);
							goto(`/games/quizzes/${quiz.id}`);
						}}
					>
						Restart
					</button> -->
					<!-- {#if anyProgress}
						<button
							class="self-center rounded-full font-bold"
							on:click={() => goto(`/games/quizzes/${quiz.id}`)}
						>
							Continue from {JSON.parse(anyProgress).length}
						</button>
					{/if} -->

					<!-- {#if conjugation.id !== 'demo'}
						<button
							class="self-center rounded-full font-bold text-red-600"
							on:click|preventDefault={async () => {
								await deleteQuiz(conjugation);
							}}
						>
							Delete
						</button>
					{/if} -->
				</div>
			</button>
		{/each}
	</div>
</section>
