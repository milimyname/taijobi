<script lang="ts">
	import {
		maxFlashcards,
		kanjiLength,
		progressSlider,
		currentAlphabet,
		selectQuizItemsForm,
		selectedQuizItems,
		swapFlashcards,
		startRangeQuizForm,
		endRangeQuizForm,
	} from '$lib/utils/stores';
	import * as Tabs from '$lib/components/ui/tabs';
	import { page } from '$app/stores';
	import { type QuizSchema } from '$lib/utils/zodSchema';
	import * as Form from '$lib/components/ui/form';
	import { type SuperForm, type Infer } from 'sveltekit-superforms';
	import Input from '$lib/components/ui/input/input.svelte';
	import Switch from '$lib/components/ui/switch/switch.svelte';
	import * as Select from '$lib/components/ui/select';
	import QuizItems from './quiz-items.svelte';
	import { Button } from '$lib/components/ui/button';
	import * as DrawerDialog from '$lib/components/ui/drawer-dialog';

	export let form: SuperForm<Infer<QuizSchema>>;

	const { form: formData, enhance } = form;

	$: if ($page.url.pathname.includes('kanji')) {
		$formData.startCount = $progressSlider === $kanjiLength ? '1' : String($progressSlider);
		$maxFlashcards = '' + $kanjiLength;
		$formData.name = '漢字';
	}

	$: if ($selectQuizItemsForm) $formData.selectedQuizItems = $selectedQuizItems.join(',');

	$: selected = {
		value: $formData.type,
		label: $formData.type,
	};

	$: choice = {
		value: $formData.choice,
		label: $formData.choice,
	};

	$endRangeQuizForm = $maxFlashcards;
</script>

<DrawerDialog.Root bind:open={$selectQuizItemsForm}>
	<DrawerDialog.Content
		className="right-0 max-md:h-full flex flex-col swap-items z-[101] md:!h-[40rem] p-0 md:!w-[40rem] max-md:fixed max-md:bottom-0 max-md:left-0 max-md:max-h-[90dvh]"
	>
		<div class="flex w-full flex-col max-md:h-full max-md:overflow-auto">
			<Tabs.Root value="range">
				<Tabs.List class="mx-4 mt-10 flex flex-1">
					<Tabs.Trigger class="flex-1" value="custom">Custom</Tabs.Trigger>
					<Tabs.Trigger class="flex-1" value="range" disabled={$selectedQuizItems.length !== 0}>
						Range
					</Tabs.Trigger>
				</Tabs.List>
				<Tabs.Content value="custom">
					<QuizItems flashcardBox={$formData.flashcardBox}>
						<DrawerDialog.Close asChild let:builder>
							<Button
								builders={[builder]}
								on:click={() => {
									$selectQuizItemsForm = false;
									$swapFlashcards = false;
									$selectedQuizItems = [];
								}}
								variant="outline"
							>
								Cancel
							</Button>
						</DrawerDialog.Close>
					</QuizItems>
				</Tabs.Content>

				<Tabs.Content value="range" class="h-[32rem] px-4">
					<div class="flex h-full flex-col justify-between">
						<div class="grid grid-cols-2 gap-2">
							<Form.Field {form} name="startCount">
								<Form.Control let:attrs>
									<Form.Label>Start</Form.Label>
									<Input
										{...attrs}
										type="number"
										min={1}
										max={+$maxFlashcards - 10}
										bind:value={$startRangeQuizForm}
									/>
								</Form.Control>
								<Form.FieldErrors />
							</Form.Field>

							<Form.Field {form} name="maxCount">
								<Form.Control let:attrs>
									<Form.Label>End ({$maxFlashcards})</Form.Label>
									<Input
										{...attrs}
										type="number"
										min={10}
										max={$maxFlashcards}
										bind:value={$endRangeQuizForm}
									/>
								</Form.Control>
								<Form.FieldErrors />
							</Form.Field>
						</div>
						<div class="flex flex-col gap-2">
							<DrawerDialog.Close asChild let:builder>
								<Button
									builders={[builder]}
									on:click={() => {
										setTimeout(() => {
											$selectQuizItemsForm = false;
											$selectedQuizItems = [];
										}, 100);
									}}
									class="w-full"
									variant="outline"
								>
									Cancel
								</Button>
							</DrawerDialog.Close>
							<DrawerDialog.Close asChild let:builder>
								<Button
									builders={[builder]}
									on:click={() => {
										$selectQuizItemsForm = false;
									}}
									class="w-full"
								>
									Save
								</Button>
							</DrawerDialog.Close>
						</div>
					</div>
				</Tabs.Content>
			</Tabs.Root>
		</div>
	</DrawerDialog.Content>
</DrawerDialog.Root>

<form method="POST" use:enhance class="quiz-form z-[99] space-y-4 max-md:px-4">
	<div class="mb-auto flex flex-col gap-4">
		<Button
			class="flex w-full items-center gap-2 rounded-md bg-gray-900 px-3.5 py-2.5 text-sm font-semibold text-white shadow-sm hover:bg-gray-800 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-gray-600"
			on:click={() => ($selectQuizItemsForm = true)}
		>
			{#if $selectedQuizItems.length !== 0}
				Selected Quiz Items ({$selectedQuizItems.length})
			{:else}
				Selected Range ({$startRangeQuizForm} - {$endRangeQuizForm})
			{/if}
		</Button>

		<Form.Field {form} name="name">
			<Form.Control let:attrs>
				<Form.Label>Name</Form.Label>
				<Input {...attrs} bind:value={$formData.name} />
			</Form.Control>
			<Form.FieldErrors />
		</Form.Field>

		<Form.Field {form} name="choice">
			<Form.Control let:attrs>
				<Form.Label>Choice</Form.Label>
				<Select.Root
					selected={choice}
					onSelectedChange={(v) => {
						v && ($formData.choice = v.value);
					}}
				>
					<Select.SelectTrigger {...attrs}>
						<Select.Value />
					</Select.SelectTrigger>
					<Select.Content>
						<Select.Item value="2">2</Select.Item>
						{#if +$maxFlashcards > 10}
							<Select.Item value="4">4</Select.Item>
						{/if}
					</Select.Content>
				</Select.Root>
				<input hidden bind:value={$formData.choice} name={attrs.name} />
			</Form.Control>
			<Form.FieldErrors />
		</Form.Field>

		<Form.Field {form} name="type">
			<Form.Control let:attrs>
				<Form.Label>Type</Form.Label>
				<Select.Root
					{selected}
					onSelectedChange={(v) => {
						v && ($formData.type = v.value);
					}}
				>
					<Select.SelectTrigger {...attrs}>
						<Select.Value />
					</Select.SelectTrigger>
					<Select.Content>
						<Select.Item value="name">name</Select.Item>
						<Select.Item value="meaning">meaning</Select.Item>
						{#if $currentAlphabet === 'kanji'}
							<Select.Item value="onyomi">onyomi</Select.Item>
							<Select.Item value="kunyomi">kunyomi</Select.Item>
						{/if}
					</Select.Content>
				</Select.Root>
				<input hidden bind:value={$formData.type} name={attrs.name} />
			</Form.Control>
			<Form.FieldErrors />
		</Form.Field>

		<Form.Field {form} name="timeLimit" class="flex items-center justify-between">
			<Form.Control let:attrs>
				<Form.Label class="flex-1">Time limit</Form.Label>
				<Switch {...attrs} bind:checked={$formData.timeLimit} />
			</Form.Control>
		</Form.Field>

		<input type="hidden" name="id" value={$formData.id} />
		<input type="hidden" name="flashcardBox" value={$formData.flashcardBox} />
		<input type="hidden" name="selectedQuizItems" value={$formData.selectedQuizItems} />
	</div>

	<button formaction="?/addQuiz" class="w-full">
		<slot name="add" />
	</button>
</form>
