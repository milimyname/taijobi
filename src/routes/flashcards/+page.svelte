<script lang="ts">
	import { clickOutside } from '$lib/utils/clickOutside';
	import { maxWidthCard, minWidthCard } from '$lib/utils/constants';
	import { onMount } from 'svelte';

	const cards = [
		'Card 1',
		'Card 2',
		'Card 3',
		'Card 4',
		'Card 5',
		'Card 6',
		'Card 7',
		'Card 8',
		'Card 9',
		'Card 10',
		'Card 11',
		'Card 12'
	];

	let touchStartY = 0;
	let touchCurrentY = 0;
	const scrollIncrement = 8; // Adjust this value to control scroll speed
	let clickedCard = false;
	let currentCardZindex: string;

	let mountedCards: NodeListOf<HTMLButtonElement>;

	onMount(() => {
		mountedCards = document.querySelectorAll('button');

		mountedCards.forEach((card, i) => {
			// Calculate the card width based on its distance from the top of the viewport
			const normalizedWidth =
				minWidthCard +
				(maxWidthCard - minWidthCard) * (card.getBoundingClientRect().top / window.innerHeight);

			// Apply the calculated width to the card
			card.style.width = `${normalizedWidth}px`;
			// Apply the calculated top position to the card
			card.style.top = `${i * (window.innerHeight / mountedCards.length)}px`;
		});
	});

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

			// Apply the calculated width to the card
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
		card.style.zIndex = '110';
	};
</script>

{#if clickedCard}
	<div class="fixed top-0 z-[100] h-screen w-full bg-black opacity-50 transition-all" />
{/if}

<section
	class="relative mt-10 flex h-screen w-full flex-col p-5"
	on:mousewheel|preventDefault={handleMouseWheel}
	on:touchstart={handleTouchStart}
	on:touchmove|preventDefault={handleTouchMove}
>
	{#each cards as card, i}
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
			class="flashcard absolute left-1/2 right-1/2 mx-auto flex h-60 w-full -translate-x-1/2 -translate-y-1/2 cursor-pointer select-none justify-center rounded-2xl bg-blue-200 p-4"
		>
			{card}
		</button>
	{/each}
</section>

<h1 class="z-[99] w-full bg-red-200 p-5 text-center">hi</h1>
