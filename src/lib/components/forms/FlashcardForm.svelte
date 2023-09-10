<script lang="ts">
	import Vault from '$lib/components/forms/Vault.svelte';
	import { clickedEditFlashcard, clickedAddFlashcard } from '$lib/utils/stores';
	import { slide } from 'svelte/transition';
	import { quintOut } from 'svelte/easing';

	export let currentFlashcardType: string;
	export let enhance: boolean;
	export let errors;
	export let form;
	export let constraints;
</script>

<Vault {enhance} notes={true}>
	{#if $clickedEditFlashcard}
		<h4 class="text-2xl">Edit flashcard</h4>
	{:else}
		<h4 class="text-2xl">Create a new flashcard</h4>
	{/if}

	<div class="mb-auto flex flex-col gap-5">
		<fieldset class=" flex w-full flex-col md:w-2/3">
			<label for="name" class="hidden">Flashcard Name</label>
			<input
				type="text"
				name="name"
				placeholder="Flashcard Name"
				class="
                    block
                    rounded-md
                    border-gray-300
                    shadow-sm
                    focus:border-indigo-300 focus:ring focus:ring-indigo-200 focus:ring-opacity-50
                  "
				aria-invalid={$errors.name ? 'true' : undefined}
				bind:value={$form.name}
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
			<label for="meaning" class="hidden">Meaning</label>
			<input
				type="text"
				name="meaning"
				placeholder="Meaning"
				class="
                    block
                    rounded-md
                    border-gray-300
                    shadow-sm
                    focus:border-indigo-300 focus:ring focus:ring-indigo-200 focus:ring-opacity-50
                  "
				aria-invalid={$errors.meaning ? 'true' : undefined}
				bind:value={$form.meaning}
				{...$constraints.meaning}
			/>
			{#if $errors.meaning}
				<span
					transition:slide={{ delay: 0, duration: 300, easing: quintOut, axis: 'y' }}
					class="mt-1 select-none text-sm text-red-400">{$errors.meaning}</span
				>
			{/if}
		</fieldset>
		{#if currentFlashcardType !== 'kanji'}
			<fieldset class=" flex w-full flex-col md:w-2/3">
				<label for="romanji" class="hidden">Romanji</label>
				<input
					type="text"
					name="romanji"
					placeholder="Romanji"
					class="
                    block
                    rounded-md
                    border-gray-300
                    shadow-sm
                    focus:border-indigo-300 focus:ring focus:ring-indigo-200 focus:ring-opacity-50
                  "
					aria-invalid={$errors.romanji ? 'true' : undefined}
					bind:value={$form.romanji}
					{...$constraints.romanji}
				/>
				{#if $errors.romanji}
					<span
						transition:slide={{ delay: 0, duration: 300, easing: quintOut, axis: 'y' }}
						class="mt-1 select-none text-sm text-red-400">{$errors.meaning}</span
					>
				{/if}
			</fieldset>
		{/if}
		<fieldset class=" flex w-full flex-col md:w-2/3">
			<select
				name="type"
				id="type"
				class="
                    block
                    rounded-md
                    border-gray-300
                    shadow-sm
                    focus:border-indigo-300 focus:ring focus:ring-indigo-200 focus:ring-opacity-50
                  "
				aria-invalid={$errors.type ? 'true' : undefined}
				bind:value={$form.type}
				{...$constraints.type}
			>
				{#if currentFlashcardType === 'kanji'}
					<option value="kanji" selected>Kanji</option>
				{:else}
					<option value="word" selected>Word</option>
				{/if}
			</select>

			{#if $errors.type}
				<span
					transition:slide={{ delay: 0, duration: 300, easing: quintOut, axis: 'y' }}
					class="mt-1 select-none text-sm text-red-400">{$errors.type}</span
				>
			{/if}
		</fieldset>
		<fieldset class=" flex w-full flex-col md:w-2/3">
			<label for="notes" class="hidden">Notes</label>
			<textarea
				name="notes"
				placeholder="Notes"
				class="
                    block
                    rounded-md
                    border-gray-300
                    shadow-sm
                    focus:border-indigo-300 focus:ring focus:ring-indigo-200 focus:ring-opacity-50
                  "
				aria-invalid={$errors.notes ? 'true' : undefined}
				bind:value={$form.notes}
				{...$constraints.notes}
				rows="3"
			/>
			{#if $errors.notes}
				<span
					transition:slide={{ delay: 0, duration: 300, easing: quintOut, axis: 'y' }}
					class="mt-1 select-none text-sm text-red-400">{$errors.notes}</span
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
			class="text-md w-full rounded-md bg-black py-2 font-medium text-white shadow-lg transition duration-200 visited:-translate-x-4 hover:bg-gray-700 active:translate-y-1 active:shadow-sm lg:w-2/3"
			>Add Flashcard</button
		>
	{/if}
</Vault>
