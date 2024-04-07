<script lang="ts">
	import type { FlashcardType, ProgressDataItem } from '$lib/utils/ambient.d.ts';
	import Quiz from './Quiz.svelte';
	import { page } from '$app/stores';
	import { shuffleArray } from '$lib/utils/actions.js';
	import { pocketbase } from '$lib/utils/pocketbase.js';
	import { onMount } from 'svelte';
	import { browser } from '$app/environment';
	import { replaceStateWithQuery } from '$lib/utils';
	import { Confetti } from 'svelte-confetti';

	export let data;

	let currentQuestion: number;

	let currentFlashcard: FlashcardType;
	let progressData: ProgressDataItem[];
	let shuffledOptions: string[] = [];
	let correctAnswers = 0;
	let flashcards: any[];
	let isWon = false;

	$: if (browser && currentFlashcard && !data.isKanjiQuiz)
		replaceStateWithQuery({
			game: 'quiz',
			alphabet: $page.params.slug,
			letter: currentFlashcard.name
		});

	const generateShuffledOptions = (options: FlashcardType[]): string[] => {
		const otherOptions = options.filter((opt) => opt.name !== currentFlashcard.name);

		shuffleArray(otherOptions);

		// Define a map of types to properties
		const typeToPropertyMap: { [key: string]: keyof FlashcardType } = {
			name: 'name',
			meaning: 'meaning',
			onyomi: 'onyomi',
			kunyomi: 'kunyomi'
		};

		const selectedProperty = typeToPropertyMap[data.quiz.type];

		if (!selectedProperty) return []; // If type doesn't match any key, return empty array

		// Handle potential undefined values when accessing properties
		const getPropertyValue = (card: FlashcardType, property: keyof FlashcardType): string => {
			const value = card[property];
			return typeof value === 'string' ? value : ''; // Return an empty string if value is undefined
		};

		switch (data.quiz.choice) {
			case '2':
				return [
					getPropertyValue(currentFlashcard, selectedProperty),
					getPropertyValue(otherOptions[0], selectedProperty)
				];
			case '4':
				return [
					getPropertyValue(currentFlashcard, selectedProperty),
					getPropertyValue(otherOptions[0], selectedProperty),
					getPropertyValue(otherOptions[1], selectedProperty),
					getPropertyValue(otherOptions[2], selectedProperty)
				];
			default:
				return [];
		}
	};

	onMount(() => {
		flashcards = JSON.parse(localStorage.getItem(`flashcards_${data.quiz.id}`) || '[]');
		if (flashcards.length > 0 && Array.isArray(flashcards)) {
			progressData = JSON.parse(localStorage.getItem(`quizProgress_${data.quiz.id}`) || '[]');
			const storedQuestionId = localStorage.getItem(`currentQuestion_${data.quiz.id}`);
			currentQuestion = storedQuestionId ? parseInt(storedQuestionId) : 0;
			currentFlashcard = flashcards[currentQuestion];

			// Get a random number between 0 and the length of the flashcards array
			shuffledOptions = generateShuffledOptions(flashcards);
		} else {
			progressData = [];
			currentQuestion = 0;
			currentFlashcard = data.flashcards[currentQuestion];

			// Get a random number between 0 and the length of the flashcards array
			shuffledOptions = generateShuffledOptions(data.flashcards);

			localStorage.setItem(`flashcards_${data.quiz.id}`, JSON.stringify(data.flashcards));
		}
	});

	async function selectAnswer(e: any, answer: string) {
		e.currentTarget?.classList.remove('bg-white');

		// Check if the user's answer is correct
		if (
			currentFlashcard.name === answer ||
			currentFlashcard.meaning === answer ||
			currentFlashcard.onyomi === answer ||
			currentFlashcard.kunyomi === answer
		) {
			e.currentTarget?.classList.add('bg-success', 'text-white');
			progressData = [
				...progressData,
				{
					name: currentFlashcard.name,
					meaning: currentFlashcard.meaning,
					kunyomi: currentFlashcard.kunyomi,
					onyomi: currentFlashcard.onyomi,
					score: 1
				}
			];
			correctAnswers++;
		} else {
			e.currentTarget?.classList.add('bg-error', 'text-white');
			progressData = [
				...progressData,
				{
					name: currentFlashcard.name,
					meaning: currentFlashcard.meaning,
					kunyomi: currentFlashcard.kunyomi,
					onyomi: currentFlashcard.onyomi,
					score: 0
				}
			];
		}

		// Check if the user has completed the entire quiz
		if (currentQuestion === data.flashcards.length - 1) {
			if (data.quiz.id !== 'hiragana' && data.quiz.id !== 'katakana') {
				// Save the user's answer when the quiz is completed
				try {
					await pocketbase.collection('quizProgress').create({
						quizId: $page.params.slug,
						userId: data.userId,
						progressData,
						correctAnswers,
						total: data.flashcards.length,
						completed: true
					});

					// Update the quiz's score
					await pocketbase.collection('quizzes').update($page.params.slug, {
						score: data.quiz.score + 1
					});
				} catch (error) {
					console.log(error);
				}
			}

			// Reset the quiz
			isWon = true;

			setTimeout(() => {
				currentQuestion = 0;
				progressData = [
					{
						name: currentFlashcard.name,
						meaning: currentFlashcard.meaning,
						kunyomi: currentFlashcard.kunyomi,
						onyomi: currentFlashcard.onyomi,
						score: 0
					}
				];
			}, 200);
			// Clear local storage
			localStorage.removeItem(`quizProgress_${data.quiz.id}`);
			localStorage.removeItem(`flashcards_${data.quiz.id}`);

			setTimeout(() => {
				localStorage.removeItem(`currentQuestion_${data.quiz.id}`);
			}, 260);
		} else {
			// Save the user's answer
			localStorage.setItem(`quizProgress_${data.quiz.id}`, JSON.stringify(progressData));
		}

		// Move to the next question
		setTimeout(() => {
			if (data.flashcards.length > currentQuestion) {
				currentQuestion++;
				localStorage.setItem(`currentQuestion_${data.quiz.id}`, '' + currentQuestion);
			}

			// Remove the background color from the previous question
			const buttons = document.querySelectorAll('button');
			buttons.forEach((button) => {
				button.classList.remove('bg-success', 'bg-error', 'text-white');
				button.classList.add('bg-white');
			});
		}, 250);
	}

	$: if (currentFlashcard && !isWon) {
		const sourceFlashcards = flashcards.length > 0 ? flashcards : data.flashcards;
		currentFlashcard = sourceFlashcards[currentQuestion];
		shuffledOptions = generateShuffledOptions(sourceFlashcards);
		shuffleArray(shuffledOptions);
	}

	$: if (isWon) setTimeout(() => (isWon = false), 5000);
</script>

{#if isWon}
	<div
		class="pointer-events-none fixed -top-1/2 left-0 flex h-screen w-screen justify-center overflow-hidden"
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

{#if currentFlashcard}
	{#if flashcards.length > 0}
		<Quiz
			flashcard={flashcards[currentQuestion]}
			ratio={currentQuestion / flashcards.length}
			type={data.quiz.type}
			{shuffledOptions}
			{selectAnswer}
		/>
	{:else}
		<Quiz
			flashcard={data.flashcards[currentQuestion]}
			ratio={currentQuestion / data.flashcards.length}
			type={data.quiz.type}
			{shuffledOptions}
			{selectAnswer}
		/>
	{/if}
{/if}
