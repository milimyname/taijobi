<script lang="ts">
	import { goto } from '$app/navigation';
	import { clickOutside } from '$lib/utils/clickOutside';
	import { maxWidthCard, minWidthCard } from '$lib/utils/constants';
	import { icons } from '$lib/utils/icons.js';
	import { onMount } from 'svelte';

	export let data;

	let cards = new Set();

	const exampleCards = [
		'Card 1',
		'Card 1',
		'Card 1',
		'Card 1',
		'Card 1',
		'Card 1',
		'Card 1',
		'Card 1'
	];

	let touchStartY = 0;
	let touchCurrentY = 0;
	const scrollIncrement = 8; // Adjust this value to control scroll speed
	let clickedCard = false;
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
		data.flashcards.forEach((card: { type: string }) => {
			cards.add(card.type);
		});

		// Example data
		cards.add('word');
		cards.add('idiom');
		cards.add('phrase');
		cards.add('random');
		cards.add('favourite');
	}

	const handleMouseWheel = (e: { deltaY: any }) => {
		const scroll = Math.sign(e.deltaY) * scrollIncrement;
		handleScroll(scroll);
	};

	const handleTouchStart = (e: { touches: { clientY: number }[] }) => {
		touchStartY = e.touches[0].clientY;
	};

	const handleTouchMove = (e: { touches: { clientY: number }[] }) => {
		touchCurrentY = e.touches[0].clientY;
		const scroll = Math.sign(touchCurrentY - touchStartY) * scrollIncrement;
		handleScroll(scroll);
		touchStartY = touchCurrentY;
	};

	// Sort the cards based on their current top position
	const sortCards = (cards: NodeListOf<HTMLButtonElement>) => {
		return Array.from(cards).sort((a, b) => {
			const topA = parseFloat(a.style.top) || 0;
			const topB = parseFloat(b.style.top) || 0;
			return topA - topB;
		});
	};

	const handleScroll = (scroll: number) => {
		// Sort the cards based on their current top position
		const sortedCards = sortCards(mountedCards);

		sortedCards.forEach((card, i) => {
			const j = i + 1;
			const top = card.style.top;
			const topNum = +top.slice(0, top.length - 2);
			const newTop = topNum + scroll;

			// Calculate the card width based on its distance from the top of the viewport
			const cardTop = card.getBoundingClientRect().top;
			const normalizedWidth =
				minWidthCard + (maxWidthCard - minWidthCard) * (cardTop / window.innerHeight);

			// // Apply the calculated width to the card
			card.style.width = `${normalizedWidth}px`;

			// Check if the card is off the section screen
			if (cardTop > window.innerHeight) {
				card.style.top = '0px';
				card.style.marginTop = `${0}px`;
				card.style.opacity = '0';
			} else if (cardTop < 0) {
				card.style.top = `${window.innerHeight - 10}px`;
				card.style.opacity = '0';
			} else {
				card.style.top = `${newTop}px`;
				card.style.opacity = '1';
				card.style.transform = 'translate(-50%, -50%) skew(0deg, 0deg)';
			}

			// Assign z-index based on the sorted order
			card.style.zIndex = `${j}`;
		});
	};

	// Sort the cards based on their current top position
	const sortCardsByTopPosition = () => {
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
		clickedCard = true;

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
</script>

{#if clickedCard}
	<div class="fixed top-0 z-[100] h-screen w-full bg-black opacity-50 transition-all" />
{/if}

<section class="z-[99] w-full py-5">
	<button
		on:click={() => {
			goto('/alphabets');
		}}
		class="flex items-center gap-2"
	>
		{@html icons.previous}
		<span>Back</span>
	</button>
</section>

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
			on:outsideclick={(e) => {
				clickedCard = false;
				e.currentTarget.style.transform = 'translate(-50%, -50%) skew(0deg, 0deg)';
				e.currentTarget.style.zIndex = currentCardZindex;
				// After resetting the clicked card, re-sort the cards by top position
				sortCardsByTopPosition();
			}}
			style={`
				box-shadow: 0px -10px 20px 0px rgba(0, 0, 0, 0.05);
				transition: transform 0.5s ease-in-out;
				top: ${i * 60}px;
				z-index: ${j};
			`}
			class="flashcard absolute left-1/2 right-1/2 mx-auto flex h-60 w-full -translate-x-1/2 -translate-y-1/2 cursor-pointer select-none flex-col items-center justify-between rounded-2xl bg-blue-200 p-4"
		>
			<h4 class="text-4xl">{card === 'kanji' ? '漢字' : card}</h4>
			<button
				on:click={() => goto(`flashcards/${card}`)}
				class="open-flashcard rounded-full bg-black px-4 py-2 text-white"
			>
				Open it
			</button>
		</button>
	{/each}
</section>
