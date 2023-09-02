<script lang="ts">
	import type { KanjiObject } from '$lib/utils/ambient.d.ts';
	import { clickedEditFlashcard, currentAlphabet, clickedAddFlashcard } from '$lib/utils/stores';
	import { cubicOut, quintOut } from 'svelte/easing';
	import { tweened } from 'svelte/motion';
	import { icons } from '$lib/utils/icons';
	import { kanji } from '$lib/static/kanji';
	import Vault from '../Vault.svelte';
	import { superForm } from 'sveltekit-superforms/client';
	import { fly, slide } from 'svelte/transition';
	import { clickOutside } from '$lib/utils/clickOutside';
	import { getRandomNumber } from '$lib/utils/actions';

	export let data;

	const rotateYCard = tweened(0, {
		duration: 2000,
		easing: cubicOut
	});

	// Get the alphabet store length
	let currentFlashcard: string;
	let currentFlashcardType: string;
	let currentKanjiObject: KanjiObject;
	let currentIndex: number = getRandomNumber(0, data.flashcards.length - 1);
	let showNotes: boolean = false;

	// Client API:
	const { form, errors, constraints, enhance } = superForm(data.form, {
		taintedMessage: null,
		onSubmit: async (form) => {
			$clickedEditFlashcard = false;
			$clickedAddFlashcard = false;
		},
		onUpdated: () => {
			if (!$errors.name) $clickedAddFlashcard = false;
		}
	});

	$: {
		if (data.flashcards.length > 0) {
			currentFlashcard = data.flashcards.at(currentIndex).name;
			currentFlashcardType = data.flashcards.at(currentIndex).type;
			currentKanjiObject = kanji[currentFlashcard];
		}
	}
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
		<fieldset class=" flex w-full flex-col md:w-2/3">
			<label for="type" class="hidden">Type</label>
			<input
				type="text"
				name="type"
				placeholder="Type"
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
			/>
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

<section
	class="flex flex-1 flex-col justify-center gap-5 sm:gap-10"
	use:clickOutside
	on:outsideclick={() => {
		$clickedAddFlashcard = false;
		// Clear the form
		$form.name = '';
		$form.meaning = '';
		$form.id = '';
		$form.notes = '';
		$form.type = '';
	}}
>
	{#if data.flashcards.length > 0}
		<div style="perspective: 3000px; position: relative;">
			<div
				style={`transform: rotateY(${-$rotateYCard}deg); transform-style: preserve-3d; backface-visibility: hidden;`}
				class="relative z-10 mx-auto cursor-pointer
				{$rotateYCard > 90 ? 'hidden' : 'block'} 
			 flex h-[504px] w-[354px] items-center justify-center rounded-xl border {currentFlashcardType ===
				'kanji'
					? 'text-[14rem]'
					: 'text-9xl'}  shadow-sm bg-dotted-spacing-8 bg-dotted-gray-200 sm:h-[600px] sm:w-[600px]"
			>
				{currentFlashcard}
				<button
					class="{showNotes && 'hidden'} 
						fixed bottom-5 right-5 z-30 rounded-full border bg-white p-2 shadow-sm transition-all"
					on:click={() => ($rotateYCard < 40 ? rotateYCard.set(180) : rotateYCard.set(0))}
				>
					{@html icons.backside}
				</button>
			</div>

			<div
				style={`transform: rotateY(${180 - $rotateYCard}deg); backface-visibility: hidden;`}
				class="relative z-10 mx-auto
				{$rotateYCard > 90 ? 'block' : 'hidden'} 
				 flex h-[504px] w-[354px] flex-col
				 {$currentAlphabet === 'kanji' ? 'gap-1' : 'gap-5'}  
				 justify-center overflow-hidden rounded-xl border p-10 shadow-sm sm:h-[600px] sm:w-[600px]"
			>
				{#if currentFlashcardType === 'kanji'}
					<div class="grid-rows-[max-content 1fr] grid h-full">
						<h2 class="text-center text-9xl">{currentFlashcard}</h2>
						<div>
							<h2 class="text-4xl font-medium">{currentKanjiObject.meaning}</h2>
							<p class=" text-sm text-gray-300">Meaning</p>
						</div>
						<div>
							<h4 class="text-lg tracking-widest">{currentKanjiObject.onyomi}</h4>
							<p class=" text-sm text-gray-300">Onyomi</p>
						</div>
						{#if currentKanjiObject.kunyomi.length > 0}
							<div>
								<h4 class="text-lg tracking-widest">{currentKanjiObject.kunyomi}</h4>
								<p class=" text-sm text-gray-300">Kunyomi</p>
							</div>
						{/if}
						{#if data.flashcards.at(currentIndex).notes.length > 0}
							<button
								class="fixed bottom-0 left-0 z-10 rounded-tr-xl {showNotes
									? 'bg-white text-black'
									: 'bg-blue-200'} p-5"
								on:click|preventDefault={() => (showNotes = !showNotes)}
							>
								{@html icons.notes}
							</button>

							<button
								class="{showNotes && 'hidden'}
								fixed bottom-5 right-5 z-30 rounded-full border bg-white p-2 shadow-sm transition-all"
								on:click={() => ($rotateYCard < 40 ? rotateYCard.set(180) : rotateYCard.set(0))}
							>
								{@html icons.backside}
							</button>

							{#if showNotes}
								<p
									transition:fly={{
										delay: 0,
										duration: 1000,
										opacity: 0,
										y: 400,
										easing: quintOut
									}}
									class="z-4 absolute bottom-0 left-0 h-5/6 w-full rounded-xl bg-primary p-4 text-sm text-white"
								>
									{data.flashcards.at(currentIndex).notes}
								</p>
							{/if}
						{/if}
					</div>
				{/if}
			</div>
		</div>
		<div class="flex items-center justify-between sm:mx-auto sm:w-[600px]">
			<button
				on:click|preventDefault={() => (currentIndex > 0 ? currentIndex-- : currentIndex)}
				class="previousLetter h-fit w-fit rounded-full border bg-white p-2 shadow-sm transition-all"
			>
				{@html icons.previous}
			</button>

			<div
				class="flex items-center justify-between gap-8 rounded-full bg-black px-4 py-2 text-white"
			>
				<button
					on:click|stopPropagation={() => {
						$clickedAddFlashcard = true;
						$clickedEditFlashcard = true;
						// Fill out the form with the current card data
						$form.name = data.flashcards.at(currentIndex).name;
						$form.meaning = data.flashcards.at(currentIndex).meaning;
						$form.id = data.flashcards.at(currentIndex).id;
						$form.notes = data.flashcards.at(currentIndex).notes;
						$form.type = 'kanji';
					}}
				>
					{@html icons.edit}
				</button>
			</div>
			<button
				on:click|preventDefault={() =>
					currentIndex < data.flashcards.length - 1 ? currentIndex++ : currentIndex}
				class="previousLetter h-fit w-fit rounded-full border bg-white p-2 shadow-sm transition-all"
			>
				{@html icons.next}
			</button>
		</div>
	{/if}
</section>
