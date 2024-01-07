<script lang="ts">
	import {
		clickedQuizForm,
		maxFlashcards,
		clickedKanjiForm,
		kanjiLength,
		progressSlider,
		currentAlphabet,
		selectQuizItemsForm,
		selectedQuizItems
	} from '$lib/utils/stores';
	import { fly, slide } from 'svelte/transition';
	import { quintOut } from 'svelte/easing';
	import { createSwitch, melt } from '@melt-ui/svelte';
	import { clickOutside } from '$lib/utils/clickOutside';
	import { Grid2X2 } from 'lucide-svelte';
	import SelectQuizItems from './SelectQuizItems.svelte';

	const {
		elements: { root, input }
	} = createSwitch();

	export let enhance: any;
	export let errors;
	export let form;
	export let constraints;

	$: {
		$form.timeLimit = $input.checked;
		$form.startCount = $progressSlider === $kanjiLength ? 1 : $progressSlider;
	}

	$: if ($selectQuizItemsForm) $form.selectedQuizItems = $selectedQuizItems;
</script>

{#if $clickedQuizForm}
	<div class="fixed top-0 z-[100] h-screen w-full bg-black opacity-50 transition-all" />
{/if}

{#if $selectQuizItemsForm}
	<SelectQuizItems flashcardBox={$form.flashcardBox} />
{/if}

{#if $clickedQuizForm}
	<form
		use:enhance
		use:clickOutside={() => {
			$clickedQuizForm = false;
			$selectedQuizItems = [];
		}}
		method="POST"
		class="quiz-form fixed -bottom-5 z-[1000] flex
		{$clickedKanjiForm ? 'h-11/12 sm:h-5/6' : ' h-[80dvh] sm:h-3/4'} 
		w-full flex-col gap-5 overflow-scroll rounded-t-2xl bg-white px-5 py-10 sm:bottom-0 md:max-w-4xl"
		transition:fly={{
			delay: 0,
			duration: 1000,
			opacity: 0,
			y: 1000,
			easing: quintOut
		}}
	>
		<h4 class="text-2xl">Create a quiz</h4>

		<div class="mb-auto flex flex-col gap-5">
			<fieldset
				class=" flex w-full flex-col gap-2"
				transition:slide={{ delay: 0, duration: 300, easing: quintOut, axis: 'y' }}
			>
				<label for="name">Quiz name</label>
				<input
					name="name"
					type="text"
					id="name"
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
			<fieldset class=" flex w-full flex-col gap-2">
				<label for="choice">Multi Choice Number</label>
				<select
					name="choice"
					id="choice"
					class="
                    block
                    rounded-md
                    border-gray-300
                    shadow-sm
                    focus:border-indigo-300 focus:ring focus:ring-indigo-200 focus:ring-opacity-50
                  "
					aria-invalid={$errors.choice ? 'true' : undefined}
					bind:value={$form.choice}
					{...$constraints.choice}
				>
					<option value="2" selected>2</option>
					{#if $maxFlashcards > '20'}
						<option value="4">4</option>
					{/if}
				</select>

				{#if $errors.choice}
					<span
						transition:slide={{ delay: 0, duration: 300, easing: quintOut, axis: 'y' }}
						class="mt-1 select-none text-sm text-red-400">{$errors.type}</span
					>
				{/if}
			</fieldset>
			<fieldset class=" flex w-full flex-col gap-2">
				<label for="type">Type</label>
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
					<option value="name" selected>name</option>
					<option value="meaning">meaning</option>
					{#if $currentAlphabet === 'kanji'}
						<option value="onyomi">onyomi</option>
						<option value="kunyomi">kunyomi</option>
					{/if}
				</select>

				{#if $errors.type}
					<span
						transition:slide={{ delay: 0, duration: 300, easing: quintOut, axis: 'y' }}
						class="mt-1 select-none text-sm text-red-400">{$errors.type}</span
					>
				{/if}
			</fieldset>

			<button
				type="button"
				class="flex gap-2 bg-slate-200 justify-start px-3 py-2 items-center rounded-md w-fit"
				on:click={() => ($selectQuizItemsForm = true)}
				transition:slide={{ delay: 0, duration: 300, easing: quintOut, axis: 'y' }}
			>
				<Grid2X2 />
				Custom Quiz Items
			</button>

			{#if $selectedQuizItems.length === 0}
				{#if $clickedKanjiForm}
					<fieldset
						class=" flex w-full flex-col gap-2"
						transition:slide={{ delay: 0, duration: 300, easing: quintOut, axis: 'y' }}
					>
						<label for="startCount">Start:</label>
						<input
							name="startCount"
							type="number"
							id="startCount"
							placeholder="Start"
							min={1}
							max={$kanjiLength - 20}
							class="
                    block
                    rounded-md
                    border-gray-300
                    shadow-sm
                    focus:border-indigo-300 focus:ring focus:ring-indigo-200 focus:ring-opacity-50
                  "
							aria-invalid={$errors.startCount ? 'true' : undefined}
							bind:value={$form.startCount}
							{...$constraints.startCount}
						/>
						{#if $errors.startCount}
							<span
								transition:slide={{ delay: 0, duration: 300, easing: quintOut, axis: 'y' }}
								class="mt-1 select-none text-sm text-red-400">{$errors.maxCount}</span
							>
						{/if}
					</fieldset>
				{/if}
				<fieldset
					class="flex w-full flex-col gap-2"
					transition:slide={{ delay: 0, duration: 300, easing: quintOut, axis: 'y' }}
				>
					<label for="maxCount">Amount of Flashcards</label>
					<input
						name="maxCount"
						type="number"
						id="maxCount"
						placeholder="Max Count"
						min="20"
						max={$maxFlashcards}
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
			{/if}

			<div class="flex items-center justify-between">
				<label for="timeLimit" id="time-limit-label"> Time limit (WIP) </label>
				<button
					use:melt={$root}
					class="switch relative h-6 w-full cursor-default rounded-full bg-slate-400 transition-colors data-[state=checked]:bg-primary"
					id="timeLimit"
					aria-labelledby="time-limit-label"
				>
					<span class="thumb block rounded-full bg-white transition" />
				</button>
				<input use:melt={$input} type="checkbox" name="timeLimit" bind:value={$form.timeLimit} />
			</div>

			{#if $errors.timeLimit && $selectedQuizItems.length !== 0}
				<span
					transition:slide={{ delay: 0, duration: 300, easing: quintOut, axis: 'y' }}
					class="mt-1 select-none text-sm text-red-400">{$errors.timeLimit}</span
				>
			{/if}
			<input type="hidden" name="flashcardBox" bind:value={$form.flashcardBox} />
			<input type="hidden" name="name" bind:value={$form.name} />
			<input type="hidden" name="selectedQuizItems" bind:value={$form.selectedQuizItems} />
		</div>

		<div class="flex w-full justify-between">
			<button
				type="button"
				on:click={() => ($clickedQuizForm = false)}
				class="text-md rounded-md border-2 border-black px-4 py-2 font-medium shadow-lg transition duration-200 visited:-translate-x-4 active:translate-y-1 active:shadow-sm"
			>
				Cancel
			</button>
			<button
				formaction="?/addQuiz"
				class="text-md rounded-md bg-black px-4 py-2 font-medium text-white shadow-lg transition duration-200 visited:-translate-x-4 hover:bg-gray-700 active:translate-y-1 active:shadow-sm"
				>Add</button
			>
		</div>
	</form>
{/if}

<style>
	.switch {
		--w: 2.75rem;
		--padding: 0.125rem;
		width: var(--w);
	}

	.thumb {
		--size: 1.25rem;
		width: var(--size);
		height: var(--size);
		transform: translateX(var(--padding));
	}

	:global([data-state='checked']) .thumb {
		transform: translateX(calc(var(--w) - var(--size) - var(--padding)));
	}
</style>
