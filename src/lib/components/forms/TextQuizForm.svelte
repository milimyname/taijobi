<script lang="ts">
	import { clickedQuizForm } from '$lib/utils/stores';
	import { fly, slide } from 'svelte/transition';
	import { quintOut } from 'svelte/easing';

	export let enhance: boolean;
	export let errors;
	export let form;
	export let constraints;
</script>

{#if $clickedQuizForm}
	<form
		use:enhance
		method="POST"
		class="quiz-form fixed -bottom-5 z-[1000] flex h-1/2 w-full flex-col gap-5 overflow-hidden rounded-t-2xl bg-white px-5 py-10 sm:bottom-0"
		transition:fly={{
			delay: 0,
			duration: 1000,
			opacity: 0,
			y: 1000,
			easing: quintOut
		}}
	>
		<h2 class="text-2xl">Work in Progress</h2>
		<h4 class="text-2xl">Create a {$form.name} quiz</h4>
		<div class="mb-auto flex flex-col gap-5">
			<input type="hidden" name="name" />
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
					<option value="2" selected>2</option>
					<option value="4" selected>4</option>
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
				<input
					name="maxCount"
					type="number"
					placeholder="Max Count"
					class="
                    block
                    rounded-md
                    border-gray-300
                    shadow-sm
                    focus:border-indigo-300 focus:ring focus:ring-indigo-200 focus:ring-opacity-50
                  "
					aria-invalid={$errors.maxCount ? 'true' : undefined}
					bind:value={$form.maxCount}
					{...$constraints.maxCount}
				/>
				{#if $errors.maxCount}
					<span
						transition:slide={{ delay: 0, duration: 300, easing: quintOut, axis: 'y' }}
						class="mt-1 select-none text-sm text-red-400">{$errors.maxCount}</span
					>
				{/if}
			</fieldset>
			<input type="hidden" name="flashcardsId" bind:value={$form.flashcardsId} />
		</div>

		<div class="flex w-full justify-between">
			<button
				type="button"
				on:click={() => ($clickedQuizForm = false)}
				class="text-md rounded-md border-2 border-black px-4 py-2 font-medium shadow-lg transition duration-200 visited:-translate-x-4 active:translate-y-1 active:shadow-sm lg:w-2/3"
				>Cancel
			</button>
			<button
				formaction="?/addTextQuiz"
				class="text-md rounded-md bg-black px-4 py-2 font-medium text-white shadow-lg transition duration-200 visited:-translate-x-4 hover:bg-gray-700 active:translate-y-1 active:shadow-sm lg:w-2/3"
				>Add</button
			>
		</div>
	</form>
{/if}
