<script lang="ts">
	import Vault from '$lib/components/forms/Vault.svelte';
	import { clickedEditFlashcard } from '$lib/utils/stores';
	import { slide } from 'svelte/transition';
	import { quintOut } from 'svelte/easing';

	export let enhance: boolean;
	export let errors;
	export let form;
	export let constraints;
</script>

<Vault {enhance}>
	<h4 class="text-2xl">Create a {$form.name} quiz</h4>
	<div class="mb-auto flex flex-col gap-5">
		<fieldset class=" flex w-full flex-col md:w-2/3">
			<label for="name" class="hidden">Collection Name</label>
			<input
				type="text"
				name="name"
				placeholder="Collection Name"
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
		<fieldset class=" flex w-full flex-col md:w-2/3">
			<label for="description" class="hidden">Description</label>
			<textarea
				name="description"
				placeholder="Description"
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
	</div>
	{#if $clickedEditFlashcard}
		<div class="flex w-full justify-between">
			<button
				formaction="?/delete"
				class="text-md rounded-md bg-red-500 px-4 py-2 font-medium text-white shadow-lg transition duration-200 visited:-translate-x-4 hover:bg-red-400 active:translate-y-1 active:shadow-sm lg:w-2/3"
				>Delete
			</button>
			<button
				formaction="?/edit"
				class="text-md rounded-md bg-black px-4 py-2 font-medium text-white shadow-lg transition duration-200 visited:-translate-x-4 hover:bg-gray-700 active:translate-y-1 active:shadow-sm lg:w-2/3"
				>Edit Flashcard</button
			>
		</div>
	{:else}
		<button
			formaction="?/add"
			class="w-full rounded-md bg-black py-2 text-lg font-medium text-white shadow-lg transition duration-200 visited:-translate-x-4 hover:bg-gray-700 active:translate-y-1 active:shadow-sm lg:w-2/3"
			>Add
		</button>
	{/if}
</Vault>
