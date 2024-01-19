<script lang="ts">
	import {
		clickedEditFlashcard,
		clickedAddFlashcardCollection,
		clickedAddFlahcardBox,
		currentFlashcardCollectionId,
		swapFlashcards,
		maxFlashcards,
		flashcardBoxes
	} from '$lib/utils/stores';
	import { fly, slide } from 'svelte/transition';
	import { quintOut } from 'svelte/easing';
	import { clickOutside } from '$lib/utils/clickOutside';
	import QuizItems from './quiz-items.svelte';

	export let enhance: any;
	export let errors;
	export let form;
	export let constraints;
</script>

{#if $swapFlashcards}
	<QuizItems flashcardBox={$form.id} />
{/if}

{#if $clickedAddFlashcardCollection || $clickedAddFlahcardBox}
	<form
		use:enhance
		use:clickOutside={() => {
			$clickedAddFlashcardCollection = false;
			$clickedAddFlahcardBox = false;
		}}
		method="POST"
		class="add-form-btn fixed -bottom-5 z-[1000] flex
				h-fit w-full flex-col gap-5 overflow-y-scroll rounded-t-2xl bg-white px-5 py-10 sm:bottom-0 md:max-w-4xl"
		transition:fly={{
			delay: 0,
			duration: 1000,
			opacity: 0,
			y: 1000,
			easing: quintOut
		}}
	>
		{#if $clickedEditFlashcard}
			<h4 class="text-2xl">Edit {$clickedAddFlashcardCollection ? 'collection' : 'box'}</h4>
		{:else}
			<h4 class="text-2xl">Add a new {$clickedAddFlashcardCollection ? 'collection' : 'box'}</h4>
		{/if}
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
			<div class="flex w-full justify-between">
				<div class="flex gap-2">
					<button
						type="button"
						on:click={() => {
							$clickedAddFlashcardCollection = false;
							$clickedAddFlahcardBox = false;
						}}
						class="text-md rounded-md border-2 border-black px-4 py-2 font-medium shadow-lg transition duration-200 visited:-translate-x-4 active:translate-y-1 active:shadow-sm"
					>
						Cancel
					</button>

					<button
						formaction="?/delete"
						class="text-md rounded-md bg-red-500 px-4 py-2 font-medium text-white shadow-lg transition duration-200 visited:-translate-x-4 hover:bg-red-400 active:translate-y-1 active:shadow-sm"
						>Delete
					</button>
				</div>
				<div class="flex gap-5">
					{#if !$clickedAddFlashcardCollection && $maxFlashcards !== '0' && $flashcardBoxes.length > 1}
						<button
							type="button"
							class="flex w-fit items-center justify-start gap-2 rounded-md bg-slate-200 px-3 py-2"
							on:click={() => ($swapFlashcards = true)}
						>
							Swap Flashcards
						</button>
					{/if}
					<button
						formaction="?/edit"
						class="text-md rounded-md bg-black px-4 py-2 font-medium text-white shadow-lg transition duration-200 visited:-translate-x-4 hover:bg-gray-700 active:translate-y-1 active:shadow-sm"
					>
						Edit {$clickedAddFlashcardCollection ? 'collection' : 'box'}
					</button>
				</div>
			</div>
		{:else}
			<button
				formaction="?/add"
				class="w-full rounded-md bg-black py-2 text-lg font-medium text-white shadow-lg transition duration-200 visited:-translate-x-4 hover:bg-gray-700 active:translate-y-1 active:shadow-sm"
			>
				Add
			</button>
		{/if}
	</form>
{/if}
