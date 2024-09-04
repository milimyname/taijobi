<script lang="ts">
	import { onMount } from 'svelte';
	import { shuffleArray } from '$lib/utils/actions';
	import Quiz from './conjugation-input.svelte';
	import { page } from '$app/stores';
	import Confetti from 'svelte-confetti';
	import type { ProgressDataItem } from '$lib/utils/ambient.d.ts';
	import QuizDrawerDialog from '$lib/components/drawer-dialogs/quiz-drawer-dialog.svelte';
	import { isHiragana } from 'wanakana';

	export let data;

	let loading = false;

	type ConjugationList = {
		name: string;
		id: string;
		flashcards: VerbConjugationResult[];
		settings?: string[];
		conjugation: VerbConjugationResult[];
	};

	type VerbConjugationResult = {
		name: string;
		positive: {
			plain: string;
			furigana: string;
			kana: string;
		};
		negative: {
			plain: string;
			furigana: string;
			kana: string;
		};
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

		const conjugations = settings
			? verb.conjugation.filter((c) => settings.includes(c.name))
			: verb.conjugation;

		shuffleArray(conjugations);

		let questionRandomIndex = Math.floor(Math.random() * conjugations.length);

		// Get random positive or negative name from conjugations
		question = conjugations[questionRandomIndex];
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

	function checkAnswer(answer: string) {
		if (isHiragana(answer))
			isCorrect = isNegative
				? question.negative.kana === answer
				: question.positive.kana === answer;
		else
			isCorrect = isNegative
				? question.negative.plain === answer
				: question.positive.plain === answer;

		console.log(question);

		if (isCorrect) {
			correctAnswers++;
			progressData = [
				...progressData,
				{
					name: isNegative
						? question.negative.plain
						: question.positive.plain + ' (' + question.name + ')',
					score: 1,
				},
			];
		} else {
			progressData = [
				...progressData,
				{
					name: isNegative
						? question.negative.plain
						: question.positive.plain + ' (' + question.name + ')',
					score: 0,
				},
			];
		}
	}

	function startOver() {
		loading = true;
		currentQuestionIndex = 0;
		currentVerbIndex = 0;
		correctAnswers = 0;
		progressData = [];
		isWon = false;
		loading = false;
	}
</script>

{#if isWon}
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
	<QuizDrawerDialog
		{loading}
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
