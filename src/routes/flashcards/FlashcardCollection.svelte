<script lang="ts">
	import { browser } from '$app/environment';
	import { onDestroy, onMount } from 'svelte';
	import {
		clickedAddFlashcardCollection,
		clickedAddFlahcardBox,
		innerWidthStore,
		currentFlashcardCollectionId,
		flashcardsBoxType,
		clickedQuizForm,
		skippedFlashcard,
		showCollections,
		clickedEditFlashcard
	} from '$lib/utils/stores';
	import { twSmallScreen } from '$lib/utils/constants';
	import { FolderEdit } from 'lucide-svelte';
	import { spring } from 'svelte/motion';
	import { goto } from '$app/navigation';
	import { page } from '$app/stores';

	export let name: string;
	export let description: string;
	export let type: string;
	export let index: number;
	export let id: number;
	export let totalCount: number;
	export let form;

	// Calculate the spring values for x, y, rotation, and scale based on index
	const x = spring(0, { stiffness: 0.1, damping: 0.8, precision: 0.1 });
	const skewX = spring(0, { stiffness: 0.1, damping: 0.5 });
	const rotateY = spring(0, { stiffness: 0.1, damping: 0.8 });
	const rotate = spring(0, { stiffness: 0.1, damping: 0.5 });
	const scale = spring(1, { stiffness: 0.1, damping: 0.8 });
	const scaleShadow = spring(0.8, { stiffness: 0.1, damping: 0.5 });

	let cardRight = 0;
	let cardLeft = 0;

	let isDragging = false;
	let cardElement: HTMLButtonElement;

	function onMouseMove(event: { clientX: number; clientY: number }) {
		if (
			index !== totalCount - 1 ||
			$showCollections ||
			$clickedAddFlashcardCollection ||
			$clickedAddFlahcardBox ||
			$clickedQuizForm
		)
			return;

		// Don't move if the mouse is in the card area, return to the intial position
		if (event.clientX > cardLeft && event.clientX < cardRight) {
			$rotateY = 0;
			$x = 0;
			$scale = 1;
			$scaleShadow = 0.8;

			return;
		}

		if (event.clientX < cardLeft) {
			$x = -150;
			$rotateY = -35;
			$scale = 1.05;
			$skewX = 12;
			$scaleShadow = 1.2;
		}

		if (event.clientX > cardRight) {
			$x = 150;
			$rotateY = 35;
			$scale = 1.05;
			$skewX = -12;
			$scaleShadow = 1.2;
		}
	}

	function onClick(event: MouseEvent) {
		if (
			(!isDragging && index !== totalCount - 1) ||
			$clickedAddFlashcardCollection ||
			$clickedAddFlahcardBox ||
			$clickedQuizForm
		)
			return;

		if ($rotateY > 15) {
			$rotateY = 60;
			$x = 1000;

			$showCollections = true;
			$currentFlashcardCollectionId = id;
			$flashcardsBoxType = type;
		}

		if ($rotateY < -15) {
			$rotateY = -60;
			$x = -1000;
			$skippedFlashcard = true;
		}
	}

	function onTouchStart(event: TouchEvent) {
		if (
			!$showCollections &&
			!$clickedQuizForm &&
			!$clickedAddFlashcardCollection &&
			!$clickedAddFlahcardBox
		)
			event.preventDefault();

		if (!isDragging && index !== totalCount - 1) return;

		// If the user clicks on the add button, don't move the card
		if (event.target?.closest('.add-btn')) {
			$clickedAddFlashcardCollection = !$clickedAddFlashcardCollection;
			return;
		}
		// If the user clicks on the add button, don't move the card
		if (event.target?.closest('.go-back-btn')) {
			$page.route.id && goto($page.route.id.length < 12 ? '/' : '/flashcards');
			return;
		}

		// If the user clicks on the add button, don't move the card
		if (event.target?.closest('.edit-collection-btn')) {
			$clickedAddFlashcardCollection = true;
			$clickedEditFlashcard = true;
			// Fill in the form with the current flashcard data
			$form.name = name;
			$form.description = description;
			$form.id = id;
			return;
		}

		isDragging = true;
	}

	function onTouchMove(event: TouchEvent) {
		if (
			!$showCollections &&
			!$clickedQuizForm &&
			!$clickedAddFlashcardCollection &&
			!$clickedAddFlahcardBox
		)
			event.preventDefault();

		if ((!isDragging && index !== totalCount - 1) || $showCollections) return;

		const touch = event.touches[0];

		// Don't move if the mouse is in the card area, return to the intial position
		if (touch.clientX > cardLeft && touch.clientX < cardRight) {
			$rotateY = 0;
			$x = 0;
			$scale = 1;
			$scaleShadow = 0.8;

			return;
		}

		if (touch.clientX < cardLeft) {
			$x = -150;
			$rotateY = -35;
			$rotate = Math.max(-35, touch.clientX - cardLeft);
			$scale = 1.05;
			$skewX = 12;

			$scaleShadow = 1.2;
		}

		if (touch.clientX > cardRight) {
			$x = 150;
			$rotateY = 35;
			$rotate = Math.min(35, touch.clientX - cardRight);
			$scale = 1.05;

			$skewX = -12;
			$scaleShadow = 1.2;
		}
	}

	function onTouchEnd(event: TouchEvent) {
		if (
			!$showCollections &&
			!$clickedQuizForm &&
			!$clickedAddFlashcardCollection &&
			!$clickedAddFlahcardBox
		)
			event.preventDefault();
		isDragging = false;

		if (!isDragging && index !== totalCount - 1) return;

		if ($rotateY > 10) {
			$rotateY = 60;
			$x = 1000;
			$showCollections = true;
			$currentFlashcardCollectionId = id;
			$flashcardsBoxType = type;
		}

		if ($rotateY < -5) {
			$rotateY = -60;
			$x = -1000;
			$skippedFlashcard = true;
		}
	}

	onMount(() => {
		window.addEventListener('touchmove', onTouchMove, { passive: false });
		window.addEventListener('touchstart', onTouchStart, { passive: false });
		window.addEventListener('touchend', onTouchEnd, { passive: false });
	});

	onDestroy(() => {
		if (!browser) return;

		window.removeEventListener('touchmove', onTouchMove);
		window.removeEventListener('touchstart', onTouchStart);
		window.removeEventListener('touchend', onTouchEnd);
	});

	$: if (browser && cardElement) {
		cardRight = cardElement.getBoundingClientRect().right;
		cardLeft = cardElement.getBoundingClientRect().left;

		if (index !== totalCount - 1) {
			$rotate = 3 + 5 * index;
			$scale = $innerWidthStore > twSmallScreen ? 1 - (totalCount - index - 1) * 0.1 : 1;
			$x = 0;
			$rotateY = 0;
		}
	}

	$: if (cardElement && !$showCollections && index === totalCount - 1) {
		$showCollections = false;
		$x = 0;
		$rotateY = 0;
		$rotate = 0;
		$scale = 1;
		$skewX = 0;
		$scaleShadow = 0.8;
	}

	$: if (cardElement && $clickedAddFlashcardCollection && index === totalCount - 1) {
		$showCollections = false;
		$x = 0;
		$rotateY = 0;
		$rotate = 0;
		$scale = 1;
		$skewX = 0;
		$scaleShadow = 0.8;
	}

	$: console.log({ type }, $page.data.isAdmin);
</script>

<svelte:window on:click={onClick} on:mousemove={onMouseMove} />

<button
	bind:this={cardElement}
	on:click={onClick}
	style="transform: translateX({$x}px) 
			rotateY({$rotateY}deg) rotate({$rotate}deg)
			translateZ({(totalCount - index) * 60}px) scale({$scale}); 
			z-index: {index};
			transform-style: preserve-3d;
			"
	class="card absolute flex h-[50dvh] w-64 select-none flex-col items-center justify-between rounded-2xl bg-white p-2 shadow-md before:absolute before:bottom-1 before:left-1 before:right-1 before:top-1 before:z-[-1] before:rounded-2xl before:bg-slate-200 sm:h-[55dvh] sm:w-80"
>
	{#if index === totalCount - 1 && totalCount > 1}
		<div
			style="
			transform: translateZ(-20rem) translateX(10px) skewX({$skewX}deg) scale({$scaleShadow})"
			class="absolute z-[-1] h-full w-full rounded-xl bg-black/5 blur-xl
			{$innerWidthStore > twSmallScreen && 'opacity-50'}"
		/>
	{/if}
	<h2>{name}</h2>
	<div class="flex h-40 w-full flex-col justify-between rounded-xl bg-blue-400 p-4">
		<span>
			{description}
		</span>

		{#if type !== 'original' || $page.data.isAdmin}
			<button
				class="edit-collection-btn self-end rounded-lg bg-white p-2"
				on:click|stopPropagation={() => {
					$clickedEditFlashcard = true;
					$clickedAddFlashcardCollection = true;
					$clickedAddFlahcardBox = false;
					$showCollections = false;

					// Fill in the form with the current flashcard data
					$form.name = name;
					$form.description = description;
					$form.id = id;
				}}
			>
				<FolderEdit />
			</button>
		{/if}
	</div>
</button>
