<script lang="ts">
	import FlashcardQuizForm from '$lib/components/forms/FlashcardQuizForm.svelte';
	import type { Card } from '$lib/utils/ambient.d.ts';
	import FlashcardsSectionForm from '$lib/components/forms/FlashcardsSectionForm.svelte';
	import { icons } from '$lib/utils/icons';
	import { goto } from '$app/navigation';
	import { clickOutside } from '$lib/utils/clickOutside';
	import { maxWidthCard, minWidthCard } from '$lib/utils/constants';
	import { onMount } from 'svelte';
	import {
		clickedAddFlashcard,
		clickedFlashCard,
		clickedEditFlashcard,
		clickedQuizForm
	} from '$lib/utils/stores.js';
	import { superForm } from 'sveltekit-superforms/client';
	import { handleScroll, sortCards } from '$lib/utils/actions.js';
	import { page } from '$app/stores';

	export let data;

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

		$form.name = '';
		$form.description = '';
		$form.id = '';

		$clickedFlashCard = false;
		$clickedEditFlashcard = false;
		$clickedAddFlashcard = false;
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
		resetForm: true,
		applyAction: true,
		onSubmit: () => {
			$clickedEditFlashcard = false;
			$clickedAddFlashcard = false;
			$clickedFlashCard = false;

			// Set other cards to be normal
			mountedCards.forEach((card) => {
				card.style.transform = 'translate(-50%, -50%) skew(0deg, 0deg)';
				card.classList.remove('pointer-events-none');
			});

			// Sort the cards based on their current top position
			const sortedCards = sortCards(mountedCards);

			// Update the z-index values based on the sorted order
			sortedCards.forEach((card, i) => {
				card.style.zIndex = `${i + 1}`;
			});
		},
		onUpdated: () => {
			if ($errors.name || $errors.description) $clickedAddFlashcard = true;
		}
	});

	$: {
		// Update the cards array when the data changes
		cards = [];

		data.flashcards.forEach((card: Card) => {
			cards.push(card);
		});
	}
</script>

<FlashcardQuizForm {enhance} {errors} {form} {constraints} />
<FlashcardsSectionForm {enhance} {errors} {form} {constraints} />

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
					{card.name}
				</h4>
				<p>{card.description}</p>
			</div>
			<div
				class="flex items-center justify-between gap-8 rounded-full bg-black px-4 py-2 text-white"
			>
				<button
					on:click|stopPropagation={() => {
						$clickedAddFlashcard = true;
						$clickedQuizForm = true;

						$form.name = card.name;
						$form.description = card.description;
						$form.id = card.id;

						// Quiz the user on the current card
						// goto(`flashcards/quiz?cardId=${card.id}`);
					}}
				>
					<svg
						xmlns="http://www.w3.org/2000/svg"
						fill="none"
						viewBox="0 0 24 24"
						stroke-width="1.5"
						stroke="currentColor"
						class="h-6 w-6"
					>
						<path
							stroke-linecap="round"
							stroke-linejoin="round"
							d="M14.25 6.087c0-.355.186-.676.401-.959.221-.29.349-.634.349-1.003 0-1.036-1.007-1.875-2.25-1.875s-2.25.84-2.25 1.875c0 .369.128.713.349 1.003.215.283.401.604.401.959v0a.64.64 0 01-.657.643 48.39 48.39 0 01-4.163-.3c.186 1.613.293 3.25.315 4.907a.656.656 0 01-.658.663v0c-.355 0-.676-.186-.959-.401a1.647 1.647 0 00-1.003-.349c-1.036 0-1.875 1.007-1.875 2.25s.84 2.25 1.875 2.25c.369 0 .713-.128 1.003-.349.283-.215.604-.401.959-.401v0c.31 0 .555.26.532.57a48.039 48.039 0 01-.642 5.056c1.518.19 3.058.309 4.616.354a.64.64 0 00.657-.643v0c0-.355-.186-.676-.401-.959a1.647 1.647 0 01-.349-1.003c0-1.035 1.008-1.875 2.25-1.875 1.243 0 2.25.84 2.25 1.875 0 .369-.128.713-.349 1.003-.215.283-.4.604-.4.959v0c0 .333.277.599.61.58a48.1 48.1 0 005.427-.63 48.05 48.05 0 00.582-4.717.532.532 0 00-.533-.57v0c-.355 0-.676.186-.959.401-.29.221-.634.349-1.003.349-1.035 0-1.875-1.007-1.875-2.25s.84-2.25 1.875-2.25c.37 0 .713.128 1.003.349.283.215.604.401.96.401v0a.656.656 0 00.658-.663 48.422 48.422 0 00-.37-5.36c-1.886.342-3.81.574-5.766.689a.578.578 0 01-.61-.58v0z"
						/>
					</svg>
				</button>

				{#if ($page.data.isAdmin && card.name !== '慣用句' && card.name !== 'にち') || (!$page.data.isAdmin && card.name !== '慣用句' && card.name !== 'にち')}
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
				{/if}
				<button
					on:click|stopPropagation={() => {
						$clickedFlashCard = false;
						$clickedEditFlashcard = false;
						$clickedAddFlashcard = false;

						localStorage.setItem(
							'isConstantFlashcard',
							card.name === '慣用句' || card.name === 'にち' ? 'true' : 'false'
						);

						goto(`flashcards/${card.id}`);
					}}
					class="open-flashcard"
				>
					{@html icons.forward}
				</button>
			</div>
		</button>
	{/each}
</section>
