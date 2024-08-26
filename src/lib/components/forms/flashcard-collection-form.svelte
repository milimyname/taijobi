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
	import { page } from '$app/stores';
	import { isDesktop } from '$lib/utils';

	export let form: SuperForm<Infer<FlashcardCollectionSchema>>;

	const { form: formData, enhance, isTainted, tainted } = form;

	function handleInput(event: Event, field: string) {
		const target = event.target as HTMLInputElement | HTMLTextAreaElement;
		$formData[field] = target.value;
	}

	$: $disabledSubmitCollection = $formData.name === '' || !isTainted($tainted);
</script>

<form method="POST" action="?/delete" use:enhance class="quiz-form z-[1000] size-full max-md:px-4">
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
				{#if $isDesktop}
					<Input {...attrs} bind:value={$formData.name} />
				{:else}
					<Input {...attrs} value={$formData.name} on:input={(e) => handleInput(e, 'name')} />
				{/if}
			</Form.Control>
			<Form.FieldErrors />
		</Form.Field>

		<Form.Field {form} name="description">
			<Form.Control let:attrs>
				<Form.Label>Description</Form.Label>

				{#if $isDesktop}
					<Textarea {...attrs} class="resize-none" bind:value={$formData.description} />
				{:else}
					<Textarea
						{...attrs}
						class="resize-none"
						value={$formData.description}
						on:change={(e) => handleInput(e, 'description')}
					/>
				{/if}
			</Form.Control>
			<Form.FieldErrors />
		</Form.Field>

		<input type="hidden" name="id" value={$formData.id} />
		<input type="hidden" name="flashcardCollection" value={$currentFlashcardCollectionId} />
	</div>
	{#if $page.data.isAdmin || $flashcardsBoxType !== 'original' || $clickedAddFlashcardCollection}
		{#if $clickedEditFlashcard}
			<button
				formaction="?/update"
				class="size-full disabled:cursor-not-allowed"
				disabled={$disabledSubmitCollection}
			>
				<slot name="update" />
			</button>
		{:else}
			<button
				formaction="?/add"
				class="size-full disabled:cursor-not-allowed"
				disabled={$disabledSubmitCollection}
			>
				<slot name="add" />
			</button>
		{/if}
	{/if}
</form>
