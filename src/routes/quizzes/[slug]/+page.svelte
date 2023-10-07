<script lang="ts">
	import Quiz from './Quiz.svelte';
	import { page } from '$app/stores';
	import { getRandomNumber, shuffleArray } from '$lib/utils/actions.js';
	import { pocketbase } from '$lib/utils/pocketbase.js';
	import { onMount } from 'svelte';

	export let data;

	let progressData: {
		name: string;
		score: number;
	}[];

	let currentQuestion: number;
	let currentFlashcard: any;
	let shuffledOptions: any[];
	let correctAnswers = 0;
	let flashcards: any[];

	onMount(() => {
		flashcards = JSON.parse(localStorage.getItem(`flashcards_${data.quiz.id}`) || '[]');
		if (flashcards.length > 0 && Array.isArray(flashcards)) {
			progressData = JSON.parse(localStorage.getItem(`quizProgress_${data.quiz.id}`) || '[]');
			currentQuestion = +localStorage.getItem(`currentQuestion_${data.quiz.id}`);
			currentFlashcard = flashcards[currentQuestion];

			// Get a random number between 0 and the length of the flashcards array
			switch (data.quiz.type) {
				case '2':
					shuffledOptions = [
						currentFlashcard.name,
						flashcards[getRandomNumber(0, flashcards.length)].name
					];
					break;
				case '4':
					shuffledOptions = [
						currentFlashcard.name,
						flashcards[getRandomNumber(0, flashcards.length)].name,
						flashcards[getRandomNumber(0, flashcards.length)].name,
						flashcards[getRandomNumber(0, flashcards.length)].name
					];
					break;
			}
		} else {
			progressData = [];
			currentQuestion = 0;
			currentFlashcard = data.flashcards[currentQuestion];

			// Get a random number between 0 and the length of the flashcards array
			switch (data.quiz.type) {
				case '2':
					shuffledOptions = [
						currentFlashcard.name,
						data.flashcards[getRandomNumber(0, data.flashcards.length)].name
					];
					break;
				case '4':
					shuffledOptions = [
						currentFlashcard.name,
						data.flashcards[getRandomNumber(0, data.flashcards.length)].name,
						data.flashcards[getRandomNumber(0, data.flashcards.length)].name,
						data.flashcards[getRandomNumber(0, data.flashcards.length)].name
					];
					break;
			}

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
		if (flashcards.length > 0) {
			currentFlashcard = flashcards[currentQuestion];

			// Get a random number between 0 and the length of the flashcards array
			switch (data.quiz.type) {
				case '2':
					shuffledOptions = [
						currentFlashcard.name,
						flashcards[getRandomNumber(0, flashcards.length)].name
					];
					break;
				case '4':
					shuffledOptions = [
						currentFlashcard.name,
						flashcards[getRandomNumber(0, flashcards.length)].name,
						flashcards[getRandomNumber(0, flashcards.length)].name,
						flashcards[getRandomNumber(0, flashcards.length)].name
					];
					break;
			}

			shuffleArray(shuffledOptions);
		} else {
			currentFlashcard = data.flashcards[currentQuestion];
			// Get a random number between 0 and the length of the flashcards array
			const randomNumber = getRandomNumber(0, data.flashcards.length);

			// Get a random number between 0 and the current question if the random number is equal to the current question
			switch (data.quiz.type) {
				case '2':
					shuffledOptions = [
						currentFlashcard.name,
						data.flashcards[
							getRandomNumber(
								0,
								randomNumber === currentQuestion
									? getRandomNumber(0, currentQuestion)
									: randomNumber
							)
						].name
					];
					break;
				case '4':
					shuffledOptions = [
						currentFlashcard.name,
						data.flashcards[
							getRandomNumber(
								0,
								randomNumber === currentQuestion
									? getRandomNumber(0, currentQuestion)
									: randomNumber
							)
						].name,
						data.flashcards[
							getRandomNumber(
								0,
								randomNumber === currentQuestion
									? getRandomNumber(0, currentQuestion)
									: randomNumber
							)
						].name,
						data.flashcards[
							getRandomNumber(
								0,
								randomNumber === currentQuestion
									? getRandomNumber(0, currentQuestion)
									: randomNumber
							)
						].name
					];

					break;
			}

			shuffleArray(shuffledOptions);
		}
	}
</script>

{#if currentFlashcard}
	{#if flashcards.length > 0}
		<Quiz flashcard={flashcards[currentQuestion]} {shuffledOptions} {selectAnswer} />
	{:else}
		<Quiz flashcard={data.flashcards[currentQuestion]} {shuffledOptions} {selectAnswer} />
	{/if}
{/if}
