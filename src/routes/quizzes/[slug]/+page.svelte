<script lang="ts">
	import Quiz from './Quiz.svelte';
	import { page } from '$app/stores';
	import { shuffleArray } from '$lib/utils/actions.js';
	import { pocketbase } from '$lib/utils/pocketbase.js';
	import { onMount } from 'svelte';

	export let data;

	let currentQuestion: number;
	let currentFlashcard: {
		name: string;
	};
	let progressData: {
		name: string;
		score: number;
	}[];
	let shuffledOptions: string[] = [];
	let correctAnswers = 0;
	let flashcards: any[];

	const generateShuffledOptions = (options: any[]): string[] => {
		const otherOptions = options.filter((opt) => opt.name !== currentFlashcard.name);

		shuffleArray(otherOptions);

		switch (data.quiz.type) {
			case '2':
				return [currentFlashcard.name, otherOptions[0].name];
			case '4':
				return [
					currentFlashcard.name,
					otherOptions[0].name,
					otherOptions[1].name,
					otherOptions[2].name
				];
			default:
				return [];
		}
	};

	onMount(() => {
		flashcards = JSON.parse(localStorage.getItem(`flashcards_${data.quiz.id}`) || '[]');
		if (flashcards.length > 0 && Array.isArray(flashcards)) {
			progressData = JSON.parse(localStorage.getItem(`quizProgress_${data.quiz.id}`) || '[]');
			currentQuestion = +localStorage.getItem(`currentQuestion_${data.quiz.id}`);
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

	async function selectAnswer(e: any, name: string) {
		// Check if the user's answer is correct
		if (currentFlashcard.name === name) {
			e.currentTarget?.classList.add('bg-success', 'text-white');
			progressData = [
				...progressData,
				{
					name: currentFlashcard.name,
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
						total: data.flashcards.length
					});
				} catch (error) {
					console.log(error);
				}

				// Update the quiz's total
				await pocketbase.collection('quizzes').update($page.params.slug, {
					total: data.quiz + 1
				});
			}

			// Reset the quiz
			alert('Quiz completed!');

			setTimeout(() => {
				currentQuestion = 0;
				progressData = [
					{
						name: currentFlashcard.name,
						score: 0
					}
				];
			}, 250);
			// Clear local storage
			localStorage.removeItem(`quizProgress_${data.quiz.id}`);
			localStorage.removeItem(`flashcards_${data.quiz.id}`);

			setTimeout(() => {
				localStorage.removeItem(`currentQuestion_${data.quiz.id}`);
			}, 260);
		}
		// Save the user's answer
		else localStorage.setItem(`quizProgress_${data.quiz.id}`, JSON.stringify(progressData));

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
			});
		}, 250);
	}

	$: if (currentFlashcard) {
		const sourceFlashcards = flashcards.length > 0 ? flashcards : data.flashcards;
		currentFlashcard = sourceFlashcards[currentQuestion];
		shuffledOptions = generateShuffledOptions(sourceFlashcards);
		shuffleArray(shuffledOptions);
	}
</script>

{#if currentFlashcard}
	{#if flashcards.length > 0}
		<Quiz
			flashcard={flashcards[currentQuestion]}
			ratio={currentQuestion / flashcards.length}
			{shuffledOptions}
			{selectAnswer}
		/>
	{:else}
		<Quiz
			flashcard={data.flashcards[currentQuestion]}
			ratio={currentQuestion / data.flashcards.length}
			{shuffledOptions}
			{selectAnswer}
		/>
	{/if}
{/if}
