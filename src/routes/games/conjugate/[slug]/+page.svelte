<script lang="ts">
	import { onMount } from 'svelte';
	import { shuffleArray } from '$lib/utils/actions';
	import Quiz from './conjugation-input.svelte';
	import { page } from '$app/stores';
	import Confetti from 'svelte-confetti';
	import type { ProgressDataItem } from '$lib/utils/ambient.d.ts';
	import QuizDrawerDialog from '$lib/components/drawer-dialogs/quiz-drawer-dialog.svelte';

	export let data;

	type ConjugationList = {
		name: string;
		id: string;
		flashcards: VerbConjugationResult[];
		settings?: string[];
	};

	type VerbConjugationResult = {
		name: string;
		positive: string;
		positive_furigana: string;
		negative: string;
		negative_furigana: string;
		furigana?: string;
	};

	// let conjugationsList: ConjugationList[] = data.conjugationDemoList[0].flashcards;
	let conjugationsList: ConjugationList[] =
		$page.params.slug === 'demo'
			? data.conjugationDemoList[0].flashcards
			: data.conjugation.flashcards;

	let settings = data.conjugation?.settings;
	let currentQuestionIndex = 0;
	let currentVerbIndex = 0;
	let question: VerbConjugationResult;
	let isCorrect: boolean | null;
	let isNewQuestion = false;
	let isWon = false;
	let correctAnswers = 0;
	let progressData: ProgressDataItem[] = [];

	// Set randomaly if the question is negative or positive
	let isNegative = Math.random() < 0.5;

	function setupNewQuestion() {
		// Filter out the verbs based on the settings

		if ($page.params.slug === 'demo')
			settings = localStorage.getItem(`conjugationSettings_${$page.params.slug}`);

		if (settings && $page.params.slug === 'demo') settings = JSON.parse(settings);

		const verb = conjugationsList[currentVerbIndex];

		let verbRandomIndex = Math.floor(Math.random() * verb.conjugation.length);

		const conjugations = settings
			? verb.conjugation.filter((c) => settings.includes(c.name))
			: verb.conjugation;

		shuffleArray(conjugations);

		let questionRandomIndex = Math.floor(Math.random() * conjugations.length);

		question = conjugations[questionRandomIndex];

		// Get random positive or negative name from  verb.conjugation[verbRandomIndex]
		question.furigana =
			Math.random() < 0.5
				? verb.conjugation[verbRandomIndex].negative_furigana
				: verb.conjugation[verbRandomIndex].positive_furigana;
	}

	onMount(() => {
		shuffleArray(conjugationsList);
		setupNewQuestion();
	});

	function nextQuestion() {
		currentQuestionIndex++;
		currentVerbIndex++;
		isNegative = Math.random() < 0.5;

		if (currentVerbIndex >= conjugationsList.length) {
			isWon = true;
			return;
		}

		setupNewQuestion();
	}

	function checkAnswer(answerType: string) {
		isCorrect = isNegative ? question.negative === answerType : question.positive === answerType;

		if (isCorrect) {
			correctAnswers++;
			progressData = [
				...progressData,
				{
					name: isNegative ? question.negative : question.positive + ' (' + question.name + ')',
					score: 1,
				},
			];
		} else {
			progressData = [
				...progressData,
				{
					name: isNegative ? question.negative : question.positive + ' (' + question.name + ')',
					score: 0,
				},
			];
		}
	}

	function startOver() {
		currentQuestionIndex = 0;
		currentVerbIndex = 0;
		correctAnswers = 0;
		progressData = [];
		isWon = false;
	}
</script>

{#if isWon}
	<div
		class="pointer-events-none fixed -top-1/2 left-0 flex z-[100] h-screen w-screen justify-center overflow-hidden"
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
	<QuizDrawerDialog
		{isWon}
		{startOver}
		{correctAnswers}
		{progressData}
		total={conjugationsList.length}
	/>
{/if}

<Quiz
	{question}
	ratio={currentQuestionIndex / conjugationsList.length}
	{checkAnswer}
	{isCorrect}
	{isNegative}
	{isNewQuestion}
	{nextQuestion}
	{isWon}
/>
