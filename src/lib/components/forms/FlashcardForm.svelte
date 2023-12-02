<script lang="ts">
	import { clickedEditFlashcard, clickedAddFlashcardCollection } from '$lib/utils/stores';
	import { slide, fly } from 'svelte/transition';
	import { quintOut } from 'svelte/easing';
	import { icons } from '$lib/utils/icons';
	import { clickOutside } from '$lib/utils/clickOutside';

	export let currentFlashcardType: string;
	export let enhance: boolean;
	export let errors;
	export let form;
	export let constraints;

	let showInfo = false;
	let type: string;

	if (currentFlashcardType) type = currentFlashcardType === 'word' ? 'word' : 'kanji';
	else type = 'word';
</script>

{#if $clickedAddFlashcardCollection}
	<form
		use:enhance
		use:clickOutside
		on:outsideclick={() => ($clickedAddFlashcardCollection = false)}
		method="POST"
		class="add-form-btn fixed -bottom-5 z-[1000] flex
				h-[90dvh] w-full
				flex-col gap-5 overflow-y-scroll rounded-t-2xl bg-white px-5 py-10 sm:bottom-0 sm:h-[75dvh] md:max-w-4xl"
		transition:fly={{
			delay: 0,
			duration: 1000,
			opacity: 0,
			y: 1000,
			easing: quintOut
		}}
	>
		{#if $clickedEditFlashcard}
			<h4 class="text-2xl">Edit flashcard</h4>
		{:else}
			<h4 class="text-2xl">Create a new flashcard</h4>
		{/if}

		<div class="mb-auto flex flex-col gap-5">
			<fieldset
				transition:slide={{ delay: 0, duration: 300, easing: quintOut, axis: 'y' }}
				class=" flex w-full flex-col"
			>
				<label for="name" class="mb-2 flex items-center gap-2">
					Flashcard

					<button
						type="button"
						on:click={() => (showInfo = true)}
						on:mouseenter={() => (showInfo = true)}
						on:mouseleave={() => (showInfo = false)}
						class="relative hover:fill-black/50"
					>
						{@html icons.question}
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
								Mostly, u won't need to use it but sometimes, there is a typo in the auto furigana
								and u can overwrite it with this. Just use slashes for hiragana after the last kanji
								one and don't forget to close it with a slash
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
			{#if currentFlashcardType !== 'kanji'}
				<fieldset class=" flex w-full flex-col">
					<label for="romanji">Romanji</label>
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
			<div class="flex w-full justify-between">
				<button
					formaction="?/delete"
					class="text-md rounded-md bg-red-500 px-4 py-2 font-medium text-white shadow-lg transition duration-200 visited:-translate-x-4 hover:bg-red-400 active:translate-y-1 active:shadow-sm"
					>Delete
				</button>
				<button
					formaction="?/edit"
					class="text-md rounded-md bg-black px-4 py-2 font-medium text-white shadow-lg transition duration-200 visited:-translate-x-4 hover:bg-gray-700 active:translate-y-1 active:shadow-sm"
					>Edit Flashcard</button
				>
			</div>
		{:else}
			<button
				formaction="?/add"
				class="text-md w-full rounded-md bg-black py-2 font-medium text-white shadow-lg transition duration-200 visited:-translate-x-4 hover:bg-gray-700 active:translate-y-1 active:shadow-sm"
				>Add Flashcard</button
			>
		{/if}
	</form>
{/if}
