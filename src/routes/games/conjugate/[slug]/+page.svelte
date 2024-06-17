<script lang="ts">
	import { onMount } from 'svelte';
	import { shuffleArray } from '$lib/utils/actions';
	import Quiz from './Quiz.svelte';
	import { page } from '$app/stores';

	export let data;

	type ConjugationList = {
		name: string;
		id: string;
		conjugation: VerbConjugationResult[];
	};

	type VerbConjugationResult = {
		name: string;
		positive: string;
		positive_furigana: string;
		negative: string;
		negative_furigana: string;
		furigana?: string;
	};

	let conjugationsList: ConjugationList[] = data.conjugationDemoList[0].data;
	let currentQuestionIndex = 0;
	let currentVerbIndex = 0;
	let question: VerbConjugationResult;
	let isCorrect: boolean | null;
	let isNewQuestion = false;

	// Set randomaly if the question is negative or positive
	let isNegative = Math.random() < 0.5;

	function setupNewQuestion() {
		// Filter out the verbs based on the settings

		let settings = localStorage.getItem(`conjugationSettings_${$page.params.slug}`);

		if (settings) settings = JSON.parse(settings);

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

		setupNewQuestion();
	}

	function checkAnswer(answerType: string) {
		isCorrect = isNegative ? question.negative === answerType : question.positive === answerType;

		console.log(isCorrect, question);
	}
</script>

<Quiz
	{question}
	ratio={currentQuestionIndex / conjugationsList.length}
	{checkAnswer}
	{isCorrect}
	{isNegative}
	{isNewQuestion}
	{nextQuestion}
/>
