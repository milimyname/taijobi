<script lang="ts">
	import { clickedEditFlashcard, currentFlashcardTypeStore } from '$lib/utils/stores';
	import { slide, fly } from 'svelte/transition';
	import { quintOut } from 'svelte/easing';
	import { HelpCircle } from 'lucide-svelte';
	import { isDesktop } from '$lib/utils';
	import type { SuperForm } from 'sveltekit-superforms/client';
	import type { ZodValidation, SuperValidated } from 'sveltekit-superforms';
	import type { AnyZodObject } from 'zod';
	import type { Writable } from 'svelte/store';

	export let form: Writable<SuperValidated<any, any>['data']>;
	export let errors: Writable<SuperValidated<any, any>['errors']> & {
		clear: () => void;
	};
	export let constraints: any; // Replace 'any' with the appropriate type
	export let enhance: SuperForm<ZodValidation<AnyZodObject>>['enhance'] = (el, events) => ({
		destroy() {}
	});

	let showInfo = false;
	let type: string;

	$: if ($currentFlashcardTypeStore)
		type = $currentFlashcardTypeStore === 'word' ? 'word' : 'kanji';
	else type = 'word';


	
	$: if (!$clickedEditFlashcard) {
		$form.name = '';
		$form.meaning = '';
		$form.id = '';
		$form.notes = '';
		$form.type = '';
		$form.romanji = '';
		$form.furigana = '';
	}
</script>

<form
	use:enhance
	method="POST"
	class="quiz-form z-[1000] flex w-full flex-col gap-5 rounded-t-2xl bg-white
        {!$isDesktop && 'px-4'}"
>
	<div class="mb-auto flex flex-col gap-5">
		<fieldset class="flex w-full flex-col">
			<label for="name" class="mb-2 flex items-center gap-2">
				Flashcard
				<button
					type="button"
					on:click={() => (showInfo = true)}
					on:mouseenter={() => (showInfo = true)}
					on:mouseleave={() => (showInfo = false)}
					class="relative hover:fill-black/50"
				>
					<HelpCircle class="h-5 w-5 transition-transform hover:scale-125" />
				</button>

				{#if showInfo}
					<div
						transition:fly={{
							delay: 0,
							duration: 1000,
							opacity: 0,
							y: 1000,
							easing: quintOut
						}}
						class="z-2 absolute bottom-0 left-0 h-2/3 w-full rounded-md bg-blue-200 p-4 text-black"
					>
						<p>If you wanna use custom furigana, please use the following format:</p>
						<ul class="my-2 text-xl">
							<li>
								<code class="text-black">漢字/かんじ/</code>
							</li>
							<li>
								<code class="text-black">読/よ/み物/もの/</code>
							</li>
						</ul>
						<p>
							Mostly, u won't need to use it but sometimes, there is a typo in the auto furigana and
							u can overwrite it with this. Just use slashes for hiragana after the last kanji one
							and don't forget to close it with a slash
						</p>
					</div>
				{/if}
			</label>
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
				{...$constraints.name}
			/>
			{#if $errors.name}
				<span
					transition:slide={{ delay: 0, duration: 300, easing: quintOut, axis: 'y' }}
					class="mt-1 select-none text-sm text-red-400"
					>{$errors.name}
				</span>
			{/if}
		</fieldset>

		<fieldset class=" flex w-full flex-col">
			<label for="meaning">Meaning</label>
			<input
				type="text"
				name="meaning"
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
		{#if $currentFlashcardTypeStore !== 'kanji'}
			<fieldset class=" flex w-full flex-col">
				<label for="romanji">Romanji/Furigana</label>
				<input
					type="text"
					name="romanji"
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
		<fieldset class=" flex w-full flex-col">
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
				bind:value={type}
				{...$constraints.type}
			>
				<option value={type}>{type}</option>
			</select>

			{#if $errors.type}
				<span
					transition:slide={{ delay: 0, duration: 300, easing: quintOut, axis: 'y' }}
					class="mt-1 select-none text-sm text-red-400">{$errors.type}</span
				>
			{/if}
		</fieldset>
		<fieldset class=" flex w-full flex-col">
			<label for="notes">Notes</label>
			<textarea
				name="notes"
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
		<div class="f flex w-full {!$isDesktop && 'flex-col gap-2'} justify-between">
			<button formaction="?/delete"><slot name="delete" /></button>

			<button formaction="?/update">
				<slot name="update" />
			</button>
		</div>
	{:else}
		<button formaction="?/add"><slot name="add" /></button>
	{/if}
</form>
