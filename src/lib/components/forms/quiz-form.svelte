<script lang="ts">
	import {
		maxFlashcards,
		kanjiLength,
		progressSlider,
		currentAlphabet,
		selectQuizItemsForm,
		selectedQuizItems
	} from '$lib/utils/stores';
	import { slide } from 'svelte/transition';
	import { quintOut } from 'svelte/easing';
	import { Switch } from '$lib/components/ui/switch';
	import type { SuperForm } from 'sveltekit-superforms/client';
	import type { ZodValidation, SuperValidated } from 'sveltekit-superforms';
	import type { AnyZodObject } from 'zod';
	import type { Writable } from 'svelte/store';
	import { isDesktop } from '$lib/utils';
	import * as Tabs from '$lib/components/ui/tabs';
	import { Button } from '$lib/components/ui/button';
	import { page } from '$app/stores';

	export let form: Writable<SuperValidated<any, any>['data']>;
	export let errors: Writable<SuperValidated<any, any>['errors']> & {
		clear: () => void;
	};
	export let constraints: any; // Replace 'any' with the appropriate type
	export let enhance: SuperForm<ZodValidation<AnyZodObject>>['enhance'] = (el, events) => ({
		destroy() {}
	});

	$: if ($page.url.pathname.includes('kanji')) {
		$form.startCount = $progressSlider === $kanjiLength ? 1 : $progressSlider;
		$maxFlashcards = '' + $kanjiLength;
	} else $form.startCount = Math.floor(Math.random() * (+$maxFlashcards - 20)) + 1;

	$: if ($selectQuizItemsForm) $form.selectedQuizItems = $selectedQuizItems;
</script>

<form
	use:enhance
	method="POST"
	class="quiz-form z-[1000] flex w-full flex-col gap-5 rounded-t-2xl bg-white
        {!$isDesktop && 'px-4'}"
>
	<div class="mb-auto flex flex-col gap-5">
		<fieldset class=" flex w-full flex-col gap-2">
			<label for="name">Name</label>
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

		<Tabs.Root value="custom">
			<Tabs.List class="flex flex-1">
				<Tabs.Trigger class="flex-1" value="custom">Custom</Tabs.Trigger>
				<Tabs.Trigger class="flex-1" value="range" disabled={$selectedQuizItems.length !== 0}>
					Range
				</Tabs.Trigger>
			</Tabs.List>
			<Tabs.Content value="custom">
				<slot />
			</Tabs.Content>
			<Tabs.Content value="range">
				<div class="flex gap-2">
					<fieldset class=" flex w-full flex-col gap-2">
						<label for="startCount">Start</label>
						<input
							name="startCount"
							type="number"
							id="startCount"
							placeholder="Start"
							min={1}
							max={+$maxFlashcards - 20}
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
					<fieldset class="flex w-full flex-col gap-2">
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
				</div>
			</Tabs.Content>
		</Tabs.Root>

		<div class="flex items-center justify-between">
			<label for="timeLimit" id="time-limit-label"> Time limit (🚧) </label>
			<Switch bind:checked={$form.timeLimit} />
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

	<Button type="submit" class="w-full" formaction="?/addQuiz">Add</Button>
</form>
