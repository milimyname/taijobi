<script lang="ts">
	import { icons } from '$lib/utils/icons';
	import Vault from './Vault.svelte';
	import { goto } from '$app/navigation';
	import { clickOutside } from '$lib/utils/clickOutside';
	import { maxWidthCard, minWidthCard } from '$lib/utils/constants';
	import { onMount } from 'svelte';
	import { slide } from 'svelte/transition';
	import { quintOut } from 'svelte/easing';
	import {
		clickedAddFlashcard,
		clickedFlashCard,
		clickedEditFlashcard,
		clickedDeleteFlashcard
	} from '$lib/utils/stores.js';
	import { superForm } from 'sveltekit-superforms/client';
	import { handleScroll, sortCards } from '$lib/utils/actions.js';

	export let data;

	type Card = {
		id: string;
		name: string;
		description: string;
	};

	let cards: Card[] = []; // Array of cards
	let touchStartY = 0;
	let touchCurrentY = 0;
	const scrollIncrement = 8; // Adjust this value to control scroll speed
	let currentCardZindex: string;

	let mountedCards: NodeListOf<HTMLButtonElement>;

	onMount(() => {
		mountedCards = document.querySelectorAll('.flashcard');

		mountedCards.forEach((card, i) => {
			// Calculate the card width based on its distance from the top of the viewport
			const normalizedWidth =
				minWidthCard +
				(maxWidthCard - minWidthCard) * (card.getBoundingClientRect().top / window.innerHeight);

			// Apply the calculated width to the card
			card.style.width = `${normalizedWidth}px`;

			if (mountedCards.length === 1)
				card.style.top = `${(i + 1) * (window.innerHeight / 3 / mountedCards.length)}px`;
			else if (mountedCards.length < 6)
				card.style.top = `${(i + 1) * (window.innerHeight / 4 / mountedCards.length)}px`;
			// Apply the calculated top position to the card
			else card.style.top = `${i * (window.innerHeight / mountedCards.length)}px`;
		});
	});

	const handleMouseWheel = (e: { deltaY: any }) => {
		const scroll = Math.sign(e.deltaY) * scrollIncrement;
		handleScroll(scroll, mountedCards);
	};

	const handleTouchStart = (e: { touches: { clientY: number }[] }) => {
		touchStartY = e.touches[0].clientY;
	};

	const handleTouchMove = (e: { touches: { clientY: number }[] }) => {
		touchCurrentY = e.touches[0].clientY;
		const scroll = Math.sign(touchCurrentY - touchStartY) * scrollIncrement;
		handleScroll(scroll, mountedCards);
		touchStartY = touchCurrentY;
	};

	// Sort the cards based on their current top position
	const handleClickFlashCardOutside = (e: {
		currentTarget: { style: { transform: string; zIndex: string } };
	}) => {
		$clickedFlashCard = false;
		$clickedEditFlashcard = false;
		$clickedAddFlashcard = false;
		$clickedDeleteFlashcard = false;
		e.currentTarget.style.transform = 'translate(-50%, -50%) skew(0deg, 0deg)';
		e.currentTarget.style.zIndex = currentCardZindex;

		// Sort the cards based on their current top position
		const sortedCards = sortCards(mountedCards);

		// Update the z-index values based on the sorted order
		sortedCards.forEach((card, i) => {
			card.style.zIndex = `${i + 1}`;
			setTimeout(() => {
				card.classList.remove('pointer-events-none');
			}, 500);
		});

		// Clear the form data
		$form.name = '';
		$form.description = '';
		$form.id = '';
	};

	const handleCardClick = (e: { currentTarget: any }) => {
		$clickedFlashCard = true;

		// Set other cards to be normal
		mountedCards.forEach((card) => {
			card.style.transform = 'translate(-50%, -50%) skew(0deg, 0deg)';
			card.classList.add('pointer-events-none');
		});

		const card = e.currentTarget;
		card.style.transform = 'translate(-50%, -100%) skew(2deg, 2deg)';
		currentCardZindex = card.style.zIndex;
		card.classList.add('pointer-events-auto');
		card.style.zIndex = '110';
	};

	// Client API:
	const { form, errors, constraints, enhance } = superForm(data.form, {
		taintedMessage: null,
		onUpdated: () => {
			if (!$errors.name || !$errors.description) $clickedAddFlashcard = false;
			$clickedFlashCard = false;
		}
	});

	$: if (!$clickedFlashCard) {
		// Clear the form data
		$form.name = '';
		$form.description = '';
		$form.id = '';
	}

	$: {
		// Update the cards array when the data changes
		cards = [];

		data.flashcards.forEach((card: Card) => {
			cards.push(card);
		});

		// Set other cards to be normal
		if (mountedCards)
			mountedCards.forEach((card) => {
				card.style.transform = 'translate(-50%, -50%) skew(0deg, 0deg)';
			});
	}
</script>

<Vault {enhance}>
	{#if $clickedEditFlashcard}
		<h4 class="text-2xl">Edit collection</h4>
	{:else if $clickedDeleteFlashcard}
		<h4 class="text-2xl">Delete collection</h4>
	{:else}
		<h4 class="text-2xl">Add a new collection</h4>
	{/if}
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
		<button
			formaction="?/edit"
			class="w-full rounded-md bg-gray-400 py-2 text-lg font-medium text-white shadow-lg transition duration-200 visited:-translate-x-4 hover:bg-gray-700 active:translate-y-1 active:shadow-sm lg:w-2/3"
			>Edit
		</button>
	{:else if $clickedDeleteFlashcard}
		<button
			formaction="?/delete"
			class="w-full rounded-md bg-red-400 py-2 text-lg font-medium text-white shadow-lg transition duration-200 visited:-translate-x-4 hover:bg-red-500 active:translate-y-1 active:shadow-sm lg:w-2/3"
			>Delete
		</button>
	{:else}
		<button
			formaction="?/add"
			class="w-full rounded-md bg-black py-2 text-lg font-medium text-white shadow-lg transition duration-200 visited:-translate-x-4 hover:bg-gray-700 active:translate-y-1 active:shadow-sm lg:w-2/3"
			>Add
		</button>
	{/if}
</Vault>

<section
	class="relative mt-10 flex h-screen w-full flex-col p-5"
	on:mousewheel|preventDefault={handleMouseWheel}
	on:touchstart={handleTouchStart}
	on:touchmove|preventDefault={handleTouchMove}
>
	{#each Array.from(cards) as card, i}
		{@const j = i + 1}
		<button
			on:click|preventDefault={handleCardClick}
			use:clickOutside
			on:outsideclick={handleClickFlashCardOutside}
			style={`
				box-shadow: 0px -10px 20px 0px rgba(0, 0, 0, 0.05);
				transition: transform 0.5s ease-in-out;
				top: ${i * 60}px;
				z-index: ${j};
			`}
			class="flashcard absolute left-1/2 right-1/2 mx-auto flex h-60 w-full -translate-x-1/2 -translate-y-1/2 cursor-pointer select-none flex-col items-center justify-between rounded-2xl bg-blue-200 p-4"
		>
			<div>
				<h4 class="break-all {card.name.length > 5 ? 'text-xl font-bold' : 'text-4xl'}">
					{card.name === 'kanji' ? '漢字' : card.name}
				</h4>
				<p>{card.description}</p>
			</div>
			<div
				class="flex {card.name !== 'kanji'
					? 'w-2/3'
					: 'gap-8'}  items-center justify-between rounded-full bg-black px-4 py-2 text-white"
			>
				{#if card.name !== 'kanji'}
					<button
						on:click|stopPropagation={() => {
							$clickedAddFlashcard = true;
							$clickedDeleteFlashcard = true;
							// Fill out the form with the current card data
							$form.name = card.name;
							$form.description = card.description;
							$form.id = card.id;
						}}
					>
						{@html icons.delete}
					</button>
				{/if}
				<button
					on:click|stopPropagation={() => {
						$clickedAddFlashcard = true;
						$clickedEditFlashcard = true;
						// Fill out the form with the current card data
						$form.name = card.name;
						$form.description = card.description;
						$form.id = card.id;
					}}
				>
					{@html icons.edit}
				</button>
				<button
					on:click|stopPropagation={() => {
						$clickedFlashCard = false;
						goto(`flashcards/${card.id}`);
					}}
					class="open-flashcard"
				>
					<svg
						xmlns="http://www.w3.org/2000/svg"
						fill="none"
						viewBox="0 0 24 24"
						stroke-width="1.5"
						stroke="currentColor"
						class="h-5 w-5"
					>
						<path
							stroke-linecap="round"
							stroke-linejoin="round"
							d="M4.5 19.5l15-15m0 0H8.25m11.25 0v11.25"
						/>
					</svg>
				</button>
			</div>
		</button>
	{/each}
</section>
