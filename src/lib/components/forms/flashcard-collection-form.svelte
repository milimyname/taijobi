<script lang="ts">
	import {
		clickedEditFlashcard,
		currentFlashcardCollectionId,
		flashcardsBoxType,
		clickedAddFlashcardCollection
	} from '$lib/utils/stores';
	import { type FlashcardCollectionSchema } from '$lib/utils/zodSchema';
	import { type SuperForm, type Infer } from 'sveltekit-superforms';
	import * as Form from '$lib/components/ui/form';
	import { Input } from '$lib/components/ui/input';
	import { Textarea } from '$lib/components/ui/textarea';
	import { cn, isDesktop } from '$lib/utils';
	import { page } from '$app/stores';

	export let form: SuperForm<Infer<FlashcardCollectionSchema>>;

	const { form: formData, enhance } = form;
</script>

<form
	method="POST"
	use:enhance
	class={cn('quiz-form z-[1000] flex w-full flex-col', !$isDesktop && 'px-4')}
>
	<div class="mb-auto flex flex-col gap-2">
		{#if !$clickedAddFlashcardCollection}
			<div class="flex gap-2">
				<Form.Field {form} name="kanjiCount">
					<Form.Control let:attrs>
						<Form.Label>Number of Kanji</Form.Label>
						<Input {...attrs} bind:value={$formData.kanjiCount} disabled />
					</Form.Control>
					<Form.FieldErrors />
				</Form.Field>

				<Form.Field {form} name="quizCount">
					<Form.Control let:attrs>
						<Form.Label>Created Quizzes</Form.Label>
						<Input {...attrs} bind:value={$formData.quizCount} disabled />
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
					bind:value={$formData.name}
					disabled={$page.data.isAdmin || $flashcardsBoxType === 'original'}
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
					bind:value={$formData.description}
					disabled={$page.data.isAdmin || $flashcardsBoxType === 'original'}
				/>
			</Form.Control>
			<Form.FieldErrors />
		</Form.Field>

		<input type="hidden" name="id" bind:value={$formData.id} />
		<input type="hidden" name="flashcardCollection" bind:value={$currentFlashcardCollectionId} />
	</div>
	{#if $page.data.isAdmin || $flashcardsBoxType !== 'original'}
		{#if $clickedEditFlashcard}
			<div class="grid grid-cols-3 gap-2">
				<button formaction="?/delete">
					<slot name="delete" />
				</button>

				<button formaction="?/update" class="col-span-2 cursor-not-allowed">
					<slot name="update" />
				</button>
			</div>
		{:else}
			<button formaction="?/add" class="cursor-not-allowed">
				<slot name="add" />
			</button>
		{/if}
	{/if}
</form>
