<script lang="ts">
	import {
		clickedEditFlashcard,
		clickedAddFlashcardCollection,
		currentFlashcardCollectionId
	} from '$lib/utils/stores';
	import { slide } from 'svelte/transition';
	import { quintOut } from 'svelte/easing';
	import type { SuperForm } from 'sveltekit-superforms/client';
	import type { ZodValidation, SuperValidated } from 'sveltekit-superforms';
	import type { AnyZodObject } from 'zod';
	import type { Writable } from 'svelte/store';
	import { isDesktop } from '$lib/utils';

	export let form: Writable<SuperValidated<any, any>['data']>;
	export let errors: Writable<SuperValidated<any, any>['errors']> & {
		clear: () => void;
	};
	export let constraints: any; // Replace 'any' with the appropriate type
	export let enhance: SuperForm<ZodValidation<AnyZodObject>>['enhance'] = (el, events) => ({
		destroy() {}
	});
</script>

<form
	use:enhance
	method="POST"
	class="quiz-form z-[1000] flex w-full flex-col gap-5 rounded-t-2xl bg-white
        {!$isDesktop && 'px-4'}"
>
	<div class="mb-auto flex flex-col gap-5">
		<fieldset class=" flex w-full flex-col md:w-full">
			<label for="name">{$clickedAddFlashcardCollection ? 'Collection' : 'Box'} Name</label>
			<input
				type="text"
				name="name"
				class="
                    block
                    rounded-md
                    border-gray-300
                    shadow-sm
                    focus:border-indigo-300 focus:ring focus:ring-indigo-200 focus:ring-opacity-50
                  "
				aria-invalid={$errors.name ? 'true' : undefined}
				bind:value={$form.name}
				disabled={$form.name === 'kanji'}
				{...$constraints.name}
			/>
			{#if $errors.name}
				<span
					transition:slide={{ delay: 0, duration: 300, easing: quintOut, axis: 'y' }}
					class="mt-1 select-none text-sm text-red-400">{$errors.name}</span
				>
			{/if}
		</fieldset>
		<fieldset class=" flex w-full flex-col md:w-full">
			<label for="description">Description</label>
			<textarea
				name="description"
				class="
                    block
                    rounded-md
                    border-gray-300
                    shadow-sm
                    focus:border-indigo-300 focus:ring focus:ring-indigo-200 focus:ring-opacity-50
                  "
				aria-invalid={$errors.description ? 'true' : undefined}
				bind:value={$form.description}
				{...$constraints.description}
				rows="3"
			/>
			{#if $errors.description}
				<span
					transition:slide={{ delay: 0, duration: 300, easing: quintOut, axis: 'y' }}
					class="mt-1 select-none text-sm text-red-400">{$errors.description}</span
				>
			{/if}
		</fieldset>

		<input type="hidden" name="id" bind:value={$form.id} />
		<input type="hidden" name="flashcardCollection" bind:value={$currentFlashcardCollectionId} />
	</div>
	{#if $clickedEditFlashcard}
		<div class="flex w-full {!$isDesktop && 'flex-col gap-2'} justify-between">
			<button formaction="?/update">
				<slot name="update" />
			</button>

			<slot name="swap" />

			<button formaction="?/delete"><slot name="delete" /></button>
		</div>
	{:else}
		<button formaction="?/add"><slot name="add" /></button>
	{/if}
</form>
