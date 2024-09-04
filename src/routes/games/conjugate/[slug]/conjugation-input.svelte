<script lang="ts">
	import Input from '$lib/components/ui/input/input.svelte';
	import { cn, getFlashcardWidth, getFlashcardHeight } from '$lib/utils';
	import { innerWidthStore, innerHeightStore } from '$lib/utils/stores';
	import Button from '$lib/components/ui/button/button.svelte';
	import { tweened } from 'svelte/motion';
	import { SendHorizonal } from 'lucide-svelte';
	import { toKana } from 'wanakana';

	export let question;
	export let checkAnswer: (answerType: string) => void;
	export let ratio: number;
	export let isCorrect: boolean | null;
	export let isNewQuestion: boolean;
	export let isNegative: boolean;
	export let nextQuestion: () => void;
	export let isWon: boolean;

	let inputValue = '';
	let isSubmitted = false;

	let tweenedRatio = tweened(0);

	function onSubmit() {
		isNewQuestion = true;
		isSubmitted = true;

		checkAnswer(inputValue);
	}

	function reset() {
		nextQuestion();
		isSubmitted = false;
		isNewQuestion = false;
		inputValue = '';
		isCorrect = null;

		// Focus on the input field
		setTimeout(() => {
			const input = document.querySelector('.conjugation-input') as HTMLInputElement;
			if (input) input.focus();
		}, 100);
	}

	$: if (inputValue && inputValue.match(/[a-zA-Z]/)) {
		// Check if last 2 letters are んa, replace them with な
		if (inputValue.slice(-2) === 'んa') inputValue = inputValue.slice(0, -2) + 'な';
		else inputValue = toKana(inputValue);
	}

	$: $tweenedRatio = ratio;
</script>

<section class="flex h-full flex-col items-center justify-center gap-4 sm:gap-5">
	<div
		style={`height: ${getFlashcardHeight($innerWidthStore, $innerHeightStore)}px;
			width: ${getFlashcardWidth($innerWidthStore)}px`}
		class={cn(
			'relative flex items-center justify-center overflow-auto rounded-xl border p-10 shadow-sm lg:my-0',
			{
				'bg-green-200': isCorrect && isSubmitted,
				'bg-red-200': !isCorrect && isSubmitted,
			},
		)}
	>
		<div class="space-y-2 text-center">
			<p>{isNegative ? 'Negative' : ''} {question?.name}</p>

			<h2 class="text-4xl">
				{@html question?.positive.furigana}
			</h2>

			{#if isSubmitted}
				<h4 class="absolute text-xl">
					{@html isNegative ? question?.negative.plain : question?.positive.plain}
				</h4>
			{/if}
		</div>

		<div
			class="absolute bottom-0 left-0 h-2 rounded-l-xl rounded-t-xl bg-black"
			style={`width: ${$tweenedRatio * 100}%`}
		/>
	</div>
	<div
		style={`width: ${getFlashcardWidth($innerWidthStore)}px;`}
		class="relative flex items-center"
	>
		<Input
			type="text"
			placeholder="Enter your answer"
			bind:value={inputValue}
			class="conjugation-input"
			disabled={isSubmitted || isNewQuestion}
			on:keydown={(e) => e.key === 'Enter' && onSubmit()}
		/>

		{#if isNewQuestion}
			<Button disabled={isWon} size="sm" class="absolute right-0 h-full" on:click={reset}>
				New Question
			</Button>
		{:else}
			<Button
				disabled={!inputValue || isSubmitted}
				size="icon"
				variant="outline"
				class="absolute right-2 my-auto size-7"
				on:click={onSubmit}
			>
				<SendHorizonal class="size-4" />
			</Button>
		{/if}
	</div>
</section>
