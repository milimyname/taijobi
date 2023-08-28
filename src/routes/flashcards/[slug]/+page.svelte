<script lang="ts">
	import type { KanjiObject } from '$lib/utils/ambient.d.ts';
	import {
		progressSlider,
		currentLetter,
		currentAlphabet,
		clickedAddFlashcard
	} from '$lib/utils/stores';
	import { cubicOut, quintOut } from 'svelte/easing';
	import { tweened } from 'svelte/motion';
	import { icons } from '$lib/utils/icons';
	import { toRomaji } from 'wanakana';
	import { kanji } from '$lib/static/kanji';
	import Vault from '../Vault.svelte';
	import { superForm } from 'sveltekit-superforms/client';
	import { slide } from 'svelte/transition';
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

	// Client API:
	const { form, errors, constraints, enhance } = superForm(data.form, {
		onUpdated: () => {
			if (!$errors.name) $clickedAddFlashcard = false;
		}
	});

	$: {
		currentFlashcard = data.flashcards.at(currentIndex).name;
		currentFlashcardType = data.flashcards.at(currentIndex).type;
		currentKanjiObject = kanji[currentFlashcard];
	}
</script>

<Vault {enhance} notes={true}>
	<h4 class="text-2xl">Create a new flashcard</h4>
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
	</div>

	<button
		class="text-md w-full rounded-md bg-black py-2 font-medium text-white shadow-lg transition duration-200 visited:-translate-x-4 hover:bg-gray-700 active:translate-y-1 active:shadow-sm lg:w-2/3"
		>Add Flashcard</button
	>
</Vault>

<section
	class="flex flex-1 flex-col justify-center gap-3 sm:gap-10"
	use:clickOutside
	on:outsideclick={() => ($clickedAddFlashcard = false)}
>
	<div style="perspective: 3000px; position: relative;" class="mb-10">
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
		</div>

		<div
			style={`transform: rotateY(${180 - $rotateYCard}deg); backface-visibility: hidden;`}
			class="relative z-10 mx-auto
				{$rotateYCard > 90 ? 'block' : 'hidden'} 
				 flex h-[504px] w-[354px] flex-col
				 {$currentAlphabet === 'kanji' ? 'gap-1' : 'gap-5'}  
				 justify-center rounded-xl border p-10 shadow-sm sm:h-[600px] sm:w-[600px]"
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
				</div>
			{/if}
		</div>

		<button
			on:click|preventDefault={() => {
				currentIndex > 0 ? currentIndex-- : currentIndex;
			}}
			class="previousLetter fixed -bottom-10 z-30 rounded-full border bg-white p-2 shadow-sm transition-all lg:left-[22rem]"
		>
			{@html icons.previous}
		</button>

		<button
			on:click|preventDefault={() => {
				currentIndex < data.flashcards.length - 1 ? currentIndex++ : currentIndex;
			}}
			class="previousLetter fixed -bottom-10 right-0 z-30 rounded-full border bg-white p-2 shadow-sm transition-all lg:right-[22rem]"
		>
			{@html icons.next}
		</button>

		<button
			class="{$rotateYCard > 5 && $rotateYCard < 175 ? 'hidden' : 'block'}
				fixed bottom-5 right-5 z-30 rounded-full border bg-white p-2 shadow-sm transition-all md:right-40 lg:right-96"
			on:click={() => {
				$rotateYCard < 40 ? rotateYCard.set(180) : rotateYCard.set(0);
			}}
		>
			{@html icons.backside}
		</button>
	</div>
</section>
