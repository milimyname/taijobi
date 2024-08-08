<script lang="ts">
	import {
		clickedEditFlashcard,
		currentFlashcardCollectionId,
		flashcardsBoxType,
		clickedAddFlashcardCollection,
		disabledSubmitCollection,
	} from '$lib/utils/stores';
	import { type FlashcardCollectionSchema } from '$lib/utils/zodSchema';
	import { type SuperForm, type Infer } from 'sveltekit-superforms';
	import * as Form from '$lib/components/ui/form';
	import { Input } from '$lib/components/ui/input';
	import { Textarea } from '$lib/components/ui/textarea';
	import { cn, isDesktop } from '$lib/utils';
	import { page } from '$app/stores';

	export let form: SuperForm<Infer<FlashcardCollectionSchema>>;

	const { form: formData, enhance, isTainted, tainted } = form;

	function handleInput(event: Event, field: string) {
		const target = event.target as HTMLInputElement | HTMLTextAreaElement;
		$formData[field] = target.value;
	}

	$: $disabledSubmitCollection = $formData.name === '' || !isTainted($tainted);
</script>

<form
	method="POST"
	action="?/delete"
	use:enhance
	class={cn('quiz-form z-[1000] w-full', !$isDesktop && 'px-4')}
>
	<div class="mb-auto flex flex-col gap-2">
		{#if $clickedEditFlashcard && !$clickedAddFlashcardCollection}
			<div class="flex gap-2">
				<Form.Field {form} name="kanjiCount" class="w-full">
					<Form.Control let:attrs>
						<Form.Label>Number of Kanji</Form.Label>
						<Input {...attrs} value={$formData.kanjiCount} disabled />
					</Form.Control>
					<Form.FieldErrors />
				</Form.Field>

				<Form.Field {form} name="quizCount" class="w-full">
					<Form.Control let:attrs>
						<Form.Label>Created Quizzes</Form.Label>
						<Input {...attrs} value={$formData.quizCount} disabled />
					</Form.Control>
					<Form.FieldErrors />
				</Form.Field>
			</div>
		{/if}

		<Form.Field {form} name="name">
			<Form.Control let:attrs>
				<Form.Label>Name</Form.Label>
				<Input
					{...attrs}
					value={$formData.name}
					on:change={(e) => handleInput(e, 'name')}
					disabled={!$page.data.isAdmin && $flashcardsBoxType === 'original'}
				/>
			</Form.Control>
			<Form.FieldErrors />
		</Form.Field>

		<Form.Field {form} name="description">
			<Form.Control let:attrs>
				<Form.Label>Description</Form.Label>
				<Textarea
					{...attrs}
					class="resize-none"
					on:change={(e) => handleInput(e, 'description')}
					value={$formData.description}
					disabled={!$page.data.isAdmin && $flashcardsBoxType === 'original'}
				/>
			</Form.Control>
			<Form.FieldErrors />
		</Form.Field>

		<input type="hidden" name="id" value={$formData.id} />
		<input type="hidden" name="flashcardCollection" value={$currentFlashcardCollectionId} />
	</div>
	{#if $page.data.isAdmin || $flashcardsBoxType !== 'original'}
		{#if $clickedEditFlashcard}
			<button
				formaction="?/update"
				class="w-full disabled:cursor-not-allowed"
				disabled={$disabledSubmitCollection}
			>
				<slot name="update" />
			</button>
		{:else}
			<button
				formaction="?/add"
				class="w-full disabled:cursor-not-allowed"
				disabled={$disabledSubmitCollection}
			>
				<slot name="add" />
			</button>
		{/if}
	{/if}
</form>
