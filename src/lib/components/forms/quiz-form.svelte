<script lang="ts">
	import {
		maxFlashcards,
		kanjiLength,
		progressSlider,
		currentAlphabet,
		selectQuizItemsForm,
		selectedQuizItems
	} from '$lib/utils/stores';
	import { isDesktop } from '$lib/utils';
	import * as Tabs from '$lib/components/ui/tabs';
	import { page } from '$app/stores';
	import { quizSchema, type QuizSchema } from '$lib/utils/zodSchema';
	import { type SuperForm } from 'sveltekit-superforms/client';
	import * as Form from '$lib/components/ui/form';

	export let form: SuperForm<QuizSchema>;

	let formData = form.form;

	$: if ($page.url.pathname.includes('kanji')) {
		$formData.startCount = $progressSlider === $kanjiLength ? 1 : $progressSlider;
		$maxFlashcards = '' + $kanjiLength;
	} else $formData.startCount = Math.floor(Math.random() * (+$maxFlashcards - 20)) + 1;

	$: if ($selectQuizItemsForm) $formData.selectedQuizItems = $selectedQuizItems.join(',');
</script>

<Form.Root
	method="POST"
	{form}
	controlled
	schema={quizSchema}
	let:config
	class="quiz-form z-[1000] flex w-full flex-col gap-5 rounded-t-2xl bg-white
        {!$isDesktop && 'px-4'}"
>
	<div class="mb-auto flex flex-col gap-2">
		<Form.Field {config} name="name">
			<Form.Item>
				<Form.Label>Name</Form.Label>
				<Form.Input />
				<Form.Validation />
			</Form.Item>
		</Form.Field>

		<Form.Field {config} name="choice">
			<Form.Item>
				<Form.Label>Multi Choice Number</Form.Label>
				<Form.Select>
					<Form.SelectTrigger />
					<Form.SelectContent>
						<Form.SelectItem value="2">2</Form.SelectItem>
						{#if $maxFlashcards > '20'}
							<Form.SelectItem value="4">4</Form.SelectItem>
						{/if}
					</Form.SelectContent>
				</Form.Select>
				<Form.Validation />
			</Form.Item>
		</Form.Field>

		<Form.Field {config} name="type">
			<Form.Item>
				<Form.Label>Type</Form.Label>
				<Form.Select>
					<Form.SelectTrigger />
					<Form.SelectContent>
						<Form.SelectItem value="name">name</Form.SelectItem>
						<Form.SelectItem value="meaning">meaning</Form.SelectItem>
						{#if $currentAlphabet === 'kanji'}
							<Form.SelectItem value="onyomi">onyomi</Form.SelectItem>
							<Form.SelectItem value="kunyomi">kunyomi</Form.SelectItem>
						{/if}
					</Form.SelectContent>
				</Form.Select>
				<Form.Validation />
			</Form.Item>
		</Form.Field>

		<Tabs.Root value="custom">
			<Tabs.List class="flex flex-1">
				<Tabs.Trigger class="flex-1" value="custom">Custom</Tabs.Trigger>
				<Tabs.Trigger class="flex-1" value="range" disabled={$selectedQuizItems.length !== 0}>
					Range
				</Tabs.Trigger>
			</Tabs.List>
			<Tabs.Content value="custom">
				<slot />
			</Tabs.Content>
			<Tabs.Content value="range">
				<div class="flex justify-between gap-2">
					<Form.Field {config} name="startCount">
						<Form.Item class="flex-1">
							<Form.Label>Start</Form.Label>
							<Form.Input type="number" min={1} max={+$maxFlashcards - 20} />
							<Form.Validation />
						</Form.Item>
					</Form.Field>
					<Form.Field {config} name="maxCount">
						<Form.Item>
							<Form.Label>Max Amount of Flashcards</Form.Label>
							<Form.Input type="number" min="20" max={$maxFlashcards} />
							<Form.Validation />
						</Form.Item>
					</Form.Field>
				</div>
			</Tabs.Content>
		</Tabs.Root>

		<Form.Field {config} name="timeLimit">
			<Form.Item class="flex items-center justify-between">
				<Form.Label class="flex-1">Time limit (🚧)</Form.Label>
				<Form.Switch />
				<Form.Validation />
			</Form.Item>
		</Form.Field>

		<Form.Field {config} name="id">
			<Form.Item>
				<Form.Input type="hidden" />
			</Form.Item>
		</Form.Field>
		<Form.Field {config} name="flashcardBox">
			<Form.Item>
				<Form.Input type="hidden" />
			</Form.Item>
		</Form.Field>
		<Form.Field {config} name="selectedQuizItems">
			<Form.Item>
				<Form.Input type="hidden" />
			</Form.Item>
		</Form.Field>
	</div>

	<Form.Button formaction="?/addQuiz">Add</Form.Button>
</Form.Root>
