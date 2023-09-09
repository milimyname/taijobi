<script lang="ts">
	import { clickedEditFlashcard, currentAlphabet, clickedAddFlashcard } from '$lib/utils/stores';
	import { cubicOut, quintOut } from 'svelte/easing';
	import { spring, tweened } from 'svelte/motion';
	import { icons } from '$lib/utils/icons';
	import { kanji } from '$lib/static/kanji';
	import { superForm } from 'sveltekit-superforms/client';
	import { fly } from 'svelte/transition';
	import { clickOutside } from '$lib/utils/clickOutside';
	import FlashcardForm from '$lib/components/forms/FlashcardForm.svelte';

	export let data;

	const rotateYCard = tweened(0, {
		duration: 2000,
		easing: cubicOut
	});

	// Get the alphabet store length
	let currentFlashcard: string;
	let currentFlashcardType: string;
	let currentIndex: number = Math.floor(data.flashcards.length / 2);
	let showNotes: boolean = false;

	// Client API:
	const { form, errors, constraints, enhance } = superForm(data.form, {
		taintedMessage: null,
		resetForm: true,
		applyAction: true,
		onSubmit: async (form) => {
			$clickedEditFlashcard = false;
			$clickedAddFlashcard = false;

			if (form.action.search.endsWith('delete')) currentIndex = 0;
		},
		onUpdated: () => {
			if (!$errors.name) $clickedAddFlashcard = false;
		}
	});

	let initialX = 0; // track the initial X position on drag start
	let initialValue = 0; // track the initial slider value on drag start
	let mousedown = false;
	let sliderWords: HTMLButtonElement;
	let currentlyCenteredWord: HTMLButtonElement;

	let progress = spring(0, {
		stiffness: 0.1,
		damping: 0.4
	});

	const start = (e: any) => {
		mousedown = true;

		initialValue = $progress; // store the initial slider value

		if (e.type === 'touchstart') initialX = e.touches[0].clientX;
		else initialX = e.clientX;
	};

	const end = () => (mousedown = false);

	const move = (e: any) => {
		if (!mousedown) return;

		let currentX;

		currentX = e.type === 'touchmove' ? e.touches[0].clientX : (currentX = e.clientX);

		const deltaX = currentX - initialX; // difference from initial position
		const sensitivity = 2; // adjust as needed for smoother or sharper response
		let change = Math.round(deltaX * sensitivity);

		// Calculate the new progress value
		const newProgress = initialValue + change;

		// Calculate the minimum and maximum values for progress
		const minProgress = -sliderWords.getBoundingClientRect().width / 2;
		const maxProgress = sliderWords.getBoundingClientRect().width / 2;

		// Check if the new progress is within the allowed range
		if (newProgress >= minProgress && newProgress <= maxProgress) {
			$progress = newProgress;
		} else if (newProgress < minProgress) {
			// If newProgress goes below the minimum, set it to the minimum
			$progress = -maxProgress;
		} else if (newProgress > maxProgress) {
			// If newProgress goes above the maximum, set it to the maximum
			$progress = maxProgress;
		}

		const words = sliderWords.querySelectorAll('button');

		words.forEach((word: HTMLButtonElement) => {
			const wordLeft = word.getBoundingClientRect().left;
			const width =
				currentFlashcardType === 'kanji'
					? word.getBoundingClientRect().width * 2
					: word.getBoundingClientRect().width;

			// Check if the word is in the middle of the screen
			if (
				wordLeft > window.innerWidth / 2 - width - 60 &&
				wordLeft < window.innerWidth / 2 + width
			) {
				// Set the current flashcard to the word in the middle of the screen
				if (word !== currentlyCenteredWord) {
					// Remove special styling from the previously centered word
					if (currentlyCenteredWord) {
						currentlyCenteredWord.classList.add('text-gray-200', 'text-2xl');
						currentlyCenteredWord.classList.remove(
							'text-black',
							'before:absolute',
							'before:-top-2',
							'before:left-1/2',
							'before:-translate-x-1/2',
							'before:bg-black',
							'before:content-[""]',
							'before:h-1',
							'before:w-1',
							'before:rounded-full',
							'text-3xl'
						);
					}
					// Apply special styling to the new centered word
					word.classList.remove('text-gray-200', 'text-2xl');
					word.classList.add(
						'text-black',
						'before:absolute',
						'before:-top-2',
						'before:left-1/2',
						'before:-translate-x-1/2',
						'before:bg-black',
						'before:content-[""]',
						'before:h-1',
						'before:w-1',
						'before:rounded-full',
						'text-3xl'
					);

					// Update the currently centered word
					currentlyCenteredWord = word;

					currentFlashcard = data.flashcards.at(
						Array.from(words).indexOf(currentlyCenteredWord)
					).name;

					currentFlashcardType = data.flashcards.at(
						Array.from(words).indexOf(currentlyCenteredWord)
					).type;

					currentIndex = Array.from(words).indexOf(currentlyCenteredWord);
				}
			} else {
				// Remove special styling from words that are no longer centered
				word.classList.add('text-gray-200', 'text-2xl');
				word.classList.remove(
					'text-black',
					'before:absolute',
					'before:-top-2',
					'before:left-1/2',
					'before:-translate-x-1/2',
					'before:bg-black',
					'before:content-[""]',
					'before:h-1',
					'before:w-1',
					'before:rounded-full',
					'text-3xl'
				);
			}

			word.style.transform = `translateX(${$progress}px)`;
		});
	};

	$: if (data.flashcards.length > 0) {
		currentFlashcard = data.flashcards.at(currentIndex).name;
		currentFlashcardType = data.flashcards.at(currentIndex).type;
	}
</script>

<FlashcardForm {currentFlashcardType} {constraints} {form} {errors} {enhance} />

<section
	class="flex flex-1 flex-col justify-center gap-5"
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
		{@const longWord = currentFlashcard.length > 8}
		<div style="perspective: 3000px; position: relative;">
			<div
				style={`transform: rotateY(${-$rotateYCard}deg); transform-style: preserve-3d; backface-visibility: hidden;`}
				class="relative z-10 mx-auto cursor-pointer
				{$rotateYCard > 90 ? 'hidden' : 'block'} 
			 flex h-[474px] w-[354px] items-center justify-center text-center {longWord
					? 'grid grid-cols-3 content-center justify-center justify-items-center gap-2'
					: 'flex-col gap-2'} overflow-hidden rounded-xl border shadow-sm bg-dotted-spacing-8 bg-dotted-gray-200 sm:h-[600px] sm:w-[600px]"
			>
				{#each currentFlashcard as letter}
					<span
						class="{longWord ? 'text-4xl' : 'text-5xl'} {currentFlashcardType === 'kanji' &&
							'text-[14rem]'} "
					>
						{letter}
					</span>
				{/each}
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
				 flex h-[474px] w-[354px] flex-col
				 {$currentAlphabet === 'kanji' ? 'gap-1' : 'gap-5'}  
				 justify-center overflow-hidden rounded-xl border p-10 shadow-sm sm:h-[600px] sm:w-[600px]"
			>
				{#if currentFlashcardType === 'kanji'}
					<div class="grid-rows-[max-content 1fr] grid h-full">
						<h2 class="text-center text-9xl">{currentFlashcard}</h2>
						<div>
							<h2 class="text-4xl font-medium">{kanji[currentFlashcard].meaning}</h2>
							<p class=" text-sm text-gray-300">Meaning</p>
						</div>
						<div>
							<h4 class="text-lg tracking-widest">{kanji[currentFlashcard].onyomi}</h4>
							<p class=" text-sm text-gray-300">Onyomi</p>
						</div>
						{#if kanji[currentFlashcard].kunyomi.length > 0}
							<div>
								<h4 class="text-lg tracking-widest">{kanji[currentFlashcard].kunyomi}</h4>
								<p class=" text-sm text-gray-300">Kunyomi</p>
							</div>
						{/if}
						{#if data.flashcards.at(currentIndex).notes && data.flashcards.at(currentIndex).notes.length > 0}
							<button
								class="fixed bottom-0 left-0 z-10 rounded-tr-xl {showNotes
									? 'bg-white text-black'
									: 'bg-blue-200'} p-5"
								on:click|preventDefault={() => (showNotes = !showNotes)}
							>
								{@html icons.notes}
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
						<button
							class="{showNotes && 'hidden'}
								fixed bottom-5 right-5 z-30 rounded-full border bg-white p-2 shadow-sm transition-all"
							on:click={() => ($rotateYCard < 40 ? rotateYCard.set(180) : rotateYCard.set(0))}
						>
							{@html icons.backside}
						</button>
					</div>
				{:else}
					<div class="grid-rows-[max-content 1fr] grid h-full">
						<h2 class="text-center text-lg">{currentFlashcard}</h2>
						<div>
							<h2 class="text-2xl font-medium">{data.flashcards.at(currentIndex).meaning}</h2>
							<p class=" text-sm text-gray-300">Meaning</p>
						</div>
						{#if data.flashcards.at(currentIndex).notes.length > 0}
							<button
								class="fixed bottom-0 left-0 z-10 rounded-tr-xl {showNotes
									? 'bg-white text-black'
									: 'bg-blue-200'} p-5"
								on:click|preventDefault={() => (showNotes = !showNotes)}
							>
								{@html icons.notes}
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
						<button
							class="{showNotes && 'hidden'}
								fixed bottom-5 right-5 z-30 rounded-full border bg-white p-2 shadow-sm transition-all"
							on:click={() => ($rotateYCard < 40 ? rotateYCard.set(180) : rotateYCard.set(0))}
						>
							{@html icons.backside}
						</button>
					</div>
				{/if}
			</div>
		</div>
		<div class="mb-auto flex items-center justify-center sm:mx-auto sm:w-[600px]">
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
						$form.type = data.flashcards.at(currentIndex).type;

						console.log(currentIndex);
					}}
				>
					{@html icons.edit}
				</button>
			</div>
		</div>

		<button
			bind:this={sliderWords}
			class="absolute bottom-5 left-1/2 flex -translate-x-1/2 cursor-ew-resize justify-between gap-5 overflow-x-hidden sm:bottom-10"
			on:mousedown|preventDefault={start}
			on:mouseup|preventDefault={end}
			on:mousemove|preventDefault={move}
			on:touchstart|preventDefault={start}
			on:touchend|preventDefault={end}
			on:touchmove|preventDefault={move}
		>
			{#each data.flashcards as { name }}
				<button
					class="relative break-keep {name.length > 5
						? 'h-12  text-sm sm:text-xl'
						: 'h-14  text-2xl'} {currentFlashcard === name
						? " text-3xl text-black before:absolute before:left-1/2 before:top-0 before:h-1.5  before:w-1.5 before:-translate-x-1/2 before:rounded-full before:bg-black before:content-['']"
						: 'text-gray-200 '}"
				>
					{name}
				</button>
			{/each}
		</button>
	{/if}
</section>
