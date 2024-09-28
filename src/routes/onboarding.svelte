<script lang="ts">
	import { fade, fly, scale } from 'svelte/transition';
	import { cubicInOut } from 'svelte/easing';
	import { AlertDialog, AlertDialogContent } from '$lib/components/ui/alert-dialog';
	import { Button } from '$lib/components/ui/button';
	import { onMount } from 'svelte';
	import { cn, getRandomHiragana, getRandomKanji, getRandomKatakana } from '$lib/utils';
	import { ArrowRight } from 'lucide-svelte';
	import Letter from '$lib/components/canvas/Letter.svelte';
	import Canvas from '$lib/components/canvas/Canvas.svelte';
	import { animateSVG, selectedLetter, strokes } from '$lib/utils/stores';
	import DrawingNavMini from '$lib/components/DrawingNavMini.svelte';
	import { toast } from 'svelte-sonner';
	import { ScrollArea } from '$lib/components/ui/scroll-area';
	import { pocketbase } from '$lib/utils/pocketbase';
	import { page } from '$app/stores';
	import type { RecordModel } from 'pocketbase';
	import { goto } from '$app/navigation';
	import Confetti from 'svelte-confetti';
	import { browser } from '$app/environment';

	let currentStep = 0;
	let isOpen = false;
	let direction = 1; // 1 for forward, -1 for backward
	let buttonVisible = false;
	let canvas: HTMLCanvasElement;
	let examples: {
		english: string;
		kana: string;
		furigana: string;
	}[] = [];
	let quizItems: {
		name: string;
		meaning: string;
	}[] = [];
	let newOnboardingBox: RecordModel;
	let newQuiz: RecordModel;

	interface Step {
		title: string;
		content: string;
	}

	const steps: Step[] = [
		{ title: 'Taijobi, huh?', content: 'Wanna check out, what can you do out here?' },
		{ title: 'Features', content: 'Check out the features of Taijobi' },
		{ title: 'Alphabets', content: 'Choose a letter to start drawing' },
		{ title: 'Drawing', content: 'Draw the letter on the canvas' },
		{ title: 'Details', content: 'Details of the letter' },
		{ title: 'Quiz', content: 'Test your knowledge with following words' },
		{ title: 'Done', content: 'You are all set to go! Go to the created quiz.' },
	];

	const languageCards = [
		{ name: 'Katakana', details: getRandomKatakana(1)[0] },
		{ name: 'Kanji', details: getRandomKanji(1)[0] },
		{ name: 'Hiragana', details: getRandomHiragana(1)[0] },
	];

	function nextStep() {
		direction = 1;
		buttonVisible = false;
		currentStep++; // Update currentStep immediately

		setTimeout(() => {
			buttonVisible = true;
		}, 300);
	}

	async function selectLanguage(language: { name: string; details: any }) {
		nextStep();

		$selectedLetter = language.details;

		$animateSVG = false;
		$strokes = [];

		setTimeout(() => ($animateSVG = true), 150);
	}

	async function generateExampleSentences() {
		try {
			const res = await fetch('/api/jisho', {
				method: 'POST',
				headers: {
					'Content-Type': 'application/json',
				},
				body: JSON.stringify({
					input: $selectedLetter?.name,
				}),
			});

			if (!res.ok) throw new Error('Failed to fetch sentence examples');

			const data: ResponseType[] = await res.json();

			if (data.length === 0) throw new Error('No examples found');

			// Check if examples are repeated, don't add them
			if (examples.length !== 0) {
				const filteredData = data.filter((d) => !examples.some((e) => e.english === d.english));
				examples = [...examples, ...filteredData];
				return;
			}

			examples = [...examples, ...data];
		} catch (e) {
			console.error(e);
			toast.error(
				'No examples found. Please try again or leave a feedback by clicking the 🐞 above. PS: Only words can have examples',
			);
		}
	}

	async function getQuizItems() {
		// Update the authStore
		pocketbase.authStore.loadFromCookie(document.cookie);
		pocketbase.authStore.onChange(() => {
			document.cookie = pocketbase.authStore.exportToCookie({ httpOnly: false });
		});

		let taijobiCollection = await pocketbase
			.collection('flashcardCollections')
			.getFirstListItem(`name = "Taijobi" && userId = "${$page.data?.user?.id}"`, {
				expand: 'flashcardBoxes',
			});

		if (!taijobiCollection) {
			taijobiCollection = await pocketbase.collection('flashcardCollections').create({
				name: 'Taijobi',
				userId: $page.data?.user?.id,
			});
		}

		// Check if the Onboarding collection exists
		const flashcardBoxes = taijobiCollection?.expand?.flashcardBoxes;

		newOnboardingBox = flashcardBoxes?.find((box) => box.name === 'Onboarding');

		if (!newOnboardingBox) {
			newOnboardingBox = await pocketbase.collection('flashcardBoxes').create({
				name: 'Onboarding',
				userId: $page.data?.user?.id,
				flashcardCollection: taijobiCollection?.id,
			});

			// Update the collection
			pocketbase.collection('flashcardCollections').update(taijobiCollection.id, {
				'flashcardBoxes+': newOnboardingBox.id,
			});
		}

		// Fetch random 10 flashcards  from flashcards collection
		const resultList = await pocketbase.collection('flashcard').getList(1, 10, {
			sort: '@random',
			fields: 'name,meaning',
		});

		quizItems = resultList.items;
	}

	async function createQuiz() {
		// Create a quiz
		newQuiz = await pocketbase.collection('quizzes').create({
			name: 'Onboarding',
			choice: '2',
			type: 'meaning',
			userId: $page.data.user.id,
			maxCount: '11',
			startCount: '1',
			flashcardBox: newOnboardingBox.id,
			flashcards: quizItems,
		});

		await pocketbase.collection('users').update($page.data.user.id, {
			'quizzes+': newQuiz.id,
		});

		// update the flashcard box
		await pocketbase.collection('flashcardBoxes').update(newOnboardingBox.id, {
			quizCount: newOnboardingBox.quizCount + 1,
		});

		nextStep();
	}

	function gotoQuiz() {
		isOpen = false;
		currentStep = 0;

		goto(`/games/quizzes/${newQuiz.id}`);

		// Set isOboarded to true
		pocketbase.collection('users').update($page.data.user.id, {
			isOnboarded: true,
		});
	}

	$: if (currentStep === 4) generateExampleSentences();

	$: if (currentStep === 5) getQuizItems();

	onMount(() => {
		isOpen = $page.data?.user?.isOnboarded ? false : true;
		setTimeout(() => {
			buttonVisible = true;
		}, 100);

		canvas = document.querySelector('canvas') as HTMLCanvasElement;
	});

	$: if ($page.data.isLoggedIn && $page.data.user.isOnboarded && browser) isOpen = false;
</script>

{#if currentStep === 6}
	<div
		class="pointer-events-none fixed -top-1/2 left-0 z-[100] flex h-screen w-screen justify-center overflow-hidden"
	>
		<Confetti
			x={[-5, 5]}
			y={[0, 0.1]}
			delay={[0, 100]}
			infinite
			duration={1000}
			amount={1000}
			fallDistance="100vh"
		/>
	</div>
{/if}

<svelte:head>
	<link href="https://fonts.googleapis.com/css2?family=Schoolbell&display=swap" rel="stylesheet" />
</svelte:head>

{#if $page.data.isLoggedIn}
	<AlertDialog bind:open={isOpen}>
		<AlertDialogContent class="z-[60] h-[90%] sm:max-w-4xl md:h-5/6">
			<div class="relative h-full w-full overflow-hidden">
				{#each steps as step, index}
					{#if index === currentStep}
						<div
							class="absolute inset-0 flex flex-col items-center justify-between md:p-6"
							in:fly={{ x: 100 * direction, duration: 300, easing: cubicInOut }}
							out:fly={{ x: -100 * direction, duration: 300, easing: cubicInOut }}
						>
							<div class="flex size-full items-center justify-center max-md:overflow-y-auto">
								{#if index === 0}
									<div class="text-center">
										<h2
											in:scale={{ duration: 300, delay: 300, easing: cubicInOut }}
											class="playful-text mb-4 text-6xl font-bold"
										>
											{step.title}
										</h2>
										<p in:fade={{ duration: 300, delay: 400 }} class="mb-6">
											{step.content}
										</p>
									</div>
								{:else if index === 1}
									<div class="grid h-full gap-2 sm:grid-cols-2 md:gap-10">
										<button
											class="flex flex-col gap-2 rounded-md border p-4 text-left"
											on:click={nextStep}
										>
											<span>Quizzes</span>
											<p>Test your knowledge with quizzes</p>
										</button>
										<button
											class="flex flex-col gap-2 rounded-md border bg-gray-50 p-4 text-left"
											on:click={() => {
												toast.info('Available in the app', {
													description: 'Please choose Quizzes for now.',
												});
											}}
										>
											<span>Paragraphs</span>
											<p>Scan and extract paragraphs from images</p>
										</button>
										<button
											class="flex flex-col gap-2 rounded-md border bg-gray-50 p-4 text-left"
											on:click={() => {
												toast.info('Available in the app', {
													description: 'Please choose Quizzes for now.',
												});
											}}
										>
											<span>Chat</span>
											<p>Chat to get your queries answered</p>
										</button>
										<button
											class="flex flex-col gap-2 rounded-md border bg-gray-50 p-4 text-left"
											on:click={() => {
												toast.info('Available in the app', {
													description: 'Please choose Quizzes for now.',
												});
											}}
										>
											<span>Search</span>
											<p>Search for saved words, phrases, and sentences</p>
										</button>
										<button
											class="flex flex-col gap-2 rounded-md border bg-gray-50 p-4 text-left"
											on:click={() => {
												toast.info('Available in the app', {
													description: 'Please choose Quizzes for now.',
												});
											}}
										>
											<span>Mode</span>
											<p>Learning mode</p>
										</button>
									</div>
								{:else if index === 2}
									<div class="flex flex-col justify-center gap-10">
										<h2
											in:scale={{ duration: 300, delay: 300, easing: cubicInOut }}
											class="playful-text mx-auto text-center text-2xl font-bold"
										>
											{step.content}
										</h2>

										<div class="flex justify-center space-x-4">
											{#each languageCards as card, index}
												<button
													on:click={() => selectLanguage(card)}
													class="transform rounded-lg bg-white p-6 shadow-lg transition-all duration-300 hover:scale-105 hover:ring-2 hover:ring-primary focus:outline-none focus:ring-2 focus:ring-primary"
													style="transform: skew({5 - index * 5}deg, {2 - index * 2}deg)"
												>
													<div class="mb-2 text-4xl">{card.details.name}</div>
													<div class="text-lg font-semibold">{card.name}</div>
												</button>
											{/each}
										</div>
									</div>
								{:else if index === 3}
									<div class="flex flex-col justify-center gap-10">
										<div style="perspective: 200px;">
											<div>
												<Canvas rotationY={0} {canvas} customWidth={380} />
												<Letter rotationY={0} className="!top-[40%]" />
												<DrawingNavMini className="mt-2" {nextStep}>
													<div class="mt-4 flex justify-center">
														{#each steps as _, index}
															<div
																class={cn('mx-1 h-2 w-2 rounded-full transition-all duration-300', {
																	'bg-primary': index === currentStep,
																	'bg-gray-300': index !== currentStep,
																})}
															/>
														{/each}
													</div>
												</DrawingNavMini>
											</div>
										</div>
									</div>
								{:else if index === 4}
									<div
										class="flex flex-col items-center space-y-4 overflow-hidden rounded-xl border p-5 shadow-sm"
									>
										<h2 class="text-4xl">{$selectedLetter?.name}</h2>
										<div>
											{#if $selectedLetter?.meaning}
												<div class="flex items-center gap-2">
													<p class="text-sm">Meaning</p>
													<p>{$selectedLetter?.meaning}</p>
												</div>
											{/if}
											{#if $selectedLetter?.onyomi && $selectedLetter?.onyomi.length > 0}
												<div class="flex items-center gap-2">
													<p class="text-sm">Onyomi</p>
													<p>{$selectedLetter?.onyomi}</p>
												</div>
											{/if}
											{#if $selectedLetter?.kunyomi && $selectedLetter?.kunyomi.length > 0}
												<div class="flex items-center gap-2">
													<p class="text-sm">Kunyomi</p>
													<p>{$selectedLetter?.kunyomi}</p>
												</div>
											{/if}
											{#if examples.length > 0}
												<div class="space-y-2">
													<p class="text-sm">Examples</p>

													<ScrollArea
														class="h-[200px] max-w-sm rounded-md border p-4"
														orientation="both"
													>
														{#each examples as example}
															<div class="flex flex-col gap-1">
																{#if example.kana}
																	<p>{@html example.kana}</p>
																{:else if example.furigana}
																	<p>{@html example.furigana}</p>
																{/if}
																<p>{example.english}</p>
															</div>
														{/each}
													</ScrollArea>
												</div>
											{:else}
												<div class="space-y-2">
													<p class="text-sm">Examples</p>

													<ScrollArea
														class="h-[200px] w-96 rounded-md border p-4"
														orientation="both"
													>
														{#each Array(3) as _}
															<div class=" mb-4 flex flex-col gap-1">
																<div class="h-4 w-3/4 animate-pulse rounded bg-gray-200"></div>
																<div class="h-4 w-full animate-pulse rounded bg-gray-200"></div>
															</div>
														{/each}
													</ScrollArea>
												</div>
											{/if}
										</div>
									</div>
								{:else if index === 5}
									<div class="h-full text-center">
										<h2
											in:scale={{ duration: 300, delay: 300, easing: cubicInOut }}
											class="playful-text mb-4 text-6xl font-bold"
										>
											{step.title}
										</h2>
										<p in:fade={{ duration: 300, delay: 400 }} class="mb-6">
											{step.content}
										</p>

										<div class="grid grid-cols-2 gap-5 sm:grid-cols-3">
											{#each quizItems as item}
												<div
													class="flex flex-col items-center gap-2 overflow-hidden rounded-xl border p-5 shadow-sm"
												>
													<p>{item.name}</p>
													<p>{item.meaning}</p>
												</div>
											{/each}
										</div>
									</div>
								{:else if index === 6}
									<div class="text-center">
										<h2
											in:scale={{ duration: 300, delay: 300, easing: cubicInOut }}
											class="playful-text mb-4 text-6xl font-bold"
										>
											{step.title}
										</h2>
										<p in:fade={{ duration: 300, delay: 400 }} class="mb-6">
											{step.content}
										</p>
									</div>
								{/if}
							</div>
						</div>
					{/if}
				{/each}
				<div class="absolute bottom-0 left-1/2 flex -translate-x-1/2 flex-col items-center gap-6">
					{#if currentStep !== 3}
						<div class="flex">
							{#each steps as _, index}
								<div
									class={cn('mx-1 h-2 w-2 rounded-full transition-all duration-300', {
										'bg-primary': index === currentStep,
										'bg-gray-300': index !== currentStep,
									})}
								/>
							{/each}
						</div>
					{/if}

					<div class="z-100 relative h-[40px]">
						{#if buttonVisible && (currentStep === 0 || currentStep === 1 || currentStep === 4)}
							<div transition:fade={{ duration: 200 }}>
								<Button
									size="icon"
									on:click={nextStep}
									class={cn('rounded-full transition-all duration-300')}
								>
									<ArrowRight class="size-5" />
								</Button>
							</div>
						{/if}
						{#if currentStep === 1 && !selectedLetter}
							<div transition:fade={{ duration: 200 }}>
								<Button
									size="icon"
									on:click={nextStep}
									class="rounded-full transition-all duration-300"
								>
									<ArrowRight class="size-5" />
								</Button>
							</div>
						{/if}

						{#if currentStep === 5}
							<div transition:fade={{ duration: 200 }}>
								<Button on:click={createQuiz} class="rounded-full transition-all duration-300">
									Create Quiz
								</Button>
							</div>
						{/if}

						{#if currentStep === 6}
							<div transition:fade={{ duration: 200 }}>
								<Button on:click={gotoQuiz} class="rounded-full transition-all duration-300">
									Go to Quiz
								</Button>
							</div>
						{/if}
					</div>
				</div>
			</div>
		</AlertDialogContent>
	</AlertDialog>
{/if}

<style>
	.playful-text {
		font-family: 'Schoolbell', cursive;
	}
</style>
