<script lang="ts">
	import Vault from './Vault.svelte';
	import { goto } from '$app/navigation';
	import { clickOutside } from '$lib/utils/clickOutside';
	import { maxWidthCard, minWidthCard } from '$lib/utils/constants';
	import { onMount } from 'svelte';
	import { slide } from 'svelte/transition';
	import { quintOut } from 'svelte/easing';
	import { clickedAddFlashcard, clickedFlashCard } from '$lib/utils/stores.js';
	import { superForm } from 'sveltekit-superforms/client';
	import { handleScroll, sortCards } from '$lib/utils/actions.js';

	export let data;

	let cards = []; // Array of cards
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
			// Apply the calculated top position to the card
			else card.style.top = `${i * (window.innerHeight / mountedCards.length)}px`;
		});
	});

	$: {
		// Populate card array from data flashcards by type
		data.flashcards.forEach((card: any) => {
			cards.push(card);
		});
	}

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
		$clickedAddFlashcard = false;
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
		onUpdated: () => {
			if (!$errors.name) $clickedAddFlashcard = false;
		}
	});
</script>

<Vault {enhance}>
	<h4 class="text-2xl">Create a new collection</h4>
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
			<input
				type="text"
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
			/>
			{#if $errors.description}
				<span
					transition:slide={{ delay: 0, duration: 300, easing: quintOut, axis: 'y' }}
					class="mt-1 select-none text-sm text-red-400">{$errors.description}</span
				>
			{/if}
		</fieldset>
	</div>
	<button
		class="text-md w-full rounded-md bg-black py-2 font-medium text-white shadow-lg transition duration-200 visited:-translate-x-4 hover:bg-gray-700 active:translate-y-1 active:shadow-sm lg:w-2/3"
		>Add Collection</button
	>
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
			<h4 class="text-4xl">{card.name === 'kanji' ? '漢字' : card.name}</h4>
			<button
				on:click|stopPropagation={() => {
					$clickedFlashCard = false;
					goto(`flashcards/${card.id}`);
				}}
				class="open-flashcard rounded-full bg-black px-4 py-2 text-white"
			>
				Open it
			</button>
		</button>
	{/each}
</section>
