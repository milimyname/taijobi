<script lang="ts">
	import {
		clickedEditFlashcard,
		clickedAddFlashcardCollection,
		currentFlashcardCollectionId
	} from '$lib/utils/stores';
	import { cn, isDesktop } from '$lib/utils';
	import { flashcardCollectionSchema, type FlashcardCollectionSchema } from '$lib/utils/zodSchema';
	import { type SuperForm } from 'sveltekit-superforms/client';
	import * as Form from '$lib/components/ui/form';

	export let form: SuperForm<FlashcardCollectionSchema>;
</script>

<Form.Root
	method="POST"
	{form}
	controlled
	schema={flashcardCollectionSchema}
	let:config
	class={cn('quiz-form z-[1000] flex w-full flex-col rounded-t-2xl', !$isDesktop && 'px-4')}
>
	<div class="mb-auto flex flex-col gap-2">
		<Form.Field {config} name="name">
			<Form.Item>
				<Form.Label>{$clickedAddFlashcardCollection ? 'Collection' : 'Box'} Name</Form.Label>
				<Form.Input />
				<Form.Validation />
			</Form.Item>
		</Form.Field>

		<Form.Field {config} name="description">
			<Form.Item>
				<Form.Label>Notes</Form.Label>
				<Form.Textarea class="resize-none" rows={3} />
				<Form.Validation />
			</Form.Item>
		</Form.Field>

		<Form.Field {config} name="id">
			<Form.Item>
				<Form.Input type="hidden" />
			</Form.Item>
		</Form.Field>
		<input type="hidden" name="flashcardCollection" bind:value={$currentFlashcardCollectionId} />
	</div>

	{#if $clickedEditFlashcard}
		<div class="grid grid-cols-3 flex-col {!$isDesktop && 'flex-col gap-2'} ">
			<button formaction="?/delete">
				<slot name="delete" />
			</button>

			<button formaction="?/update" class="col-span-2">
				<slot name="update" />
			</button>
		</div>
	{:else}
		<button formaction="?/add">
			<slot name="add" />
		</button>
	{/if}
</Form.Root>
