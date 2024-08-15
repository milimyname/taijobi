<script lang="ts">
	import {
		maxFlashcards,
		kanjiLength,
		progressSlider,
		currentAlphabet,
		selectQuizItemsForm,
		selectedQuizItems,
		startRangeQuizForm,
		endRangeQuizForm,
	} from '$lib/utils/stores';
	import { page } from '$app/stores';
	import { type QuizSchema } from '$lib/utils/zodSchema';
	import * as Form from '$lib/components/ui/form';
	import { type SuperForm, type Infer } from 'sveltekit-superforms';
	import Input from '$lib/components/ui/input/input.svelte';
	import Switch from '$lib/components/ui/switch/switch.svelte';
	import * as Select from '$lib/components/ui/select';
	import { Button } from '$lib/components/ui/button';

	export let form: SuperForm<Infer<QuizSchema>>;

	const { form: formData, enhance } = form;

	$: if ($page.url.pathname.includes('kanji')) {
		$formData.startCount = $progressSlider === $kanjiLength ? '1' : String($progressSlider);
		$maxFlashcards = '' + $kanjiLength;
		$formData.name = '漢字';
	}

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

	<button formaction="/flashcards?/addQuiz" class="w-full">
		<slot name="add" />
	</button>
</form>
