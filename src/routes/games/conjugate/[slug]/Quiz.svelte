<script lang="ts">
	import Input from '$lib/components/ui/input/input.svelte';
	import { cn, getFlashcardWidth, getFlashcardHeight, isNonJapanase } from '$lib/utils';
	import { innerWidthStore, innerHeightStore } from '$lib/utils/stores';
	import Button from '$lib/components/ui/button/button.svelte';
	import { tweened } from 'svelte/motion';
	import { SendHorizonal } from 'lucide-svelte';
	import { toast } from 'svelte-sonner';

	export let question;
	export let checkAnswer: (answerType: string) => void;
	export let ratio: number;
	export let isCorrect: boolean | null;
	export let isNewQuestion: boolean;
	export let isNegative: boolean;
	export let nextQuestion: () => void;

	let inputValue = '';
	let isSubmitted = false;

	let tweenedRatio = tweened(0);

	function onSubmit() {
		if (isNonJapanase(inputValue)) {
			inputValue = '';
			toast.error('Please enter valid kana and kanji characters');
			return;
		}

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
		<div class="text-center space-y-2">
			<p>{isNegative ? 'Negative' : ''} {question?.name}</p>

			<h2 class="text-4xl">
				{@html question?.furigana}
			</h2>

			{#if isSubmitted}
				<h4 class="text-xl absolute">
					{@html isNegative ? question?.negative : question?.positive}
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
			disabled={isSubmitted || isNewQuestion}
			on:keydown={(e) => e.key === 'Enter' && onSubmit()}
		/>

		{#if isNewQuestion}
			<Button size="sm" class="absolute h-full right-0" on:click={reset}>New Question</Button>
		{:else}
			<Button
				disabled={!inputValue || isSubmitted}
				size="icon"
				variant="outline"
				class="absolute size-7 my-auto right-2"
				on:click={onSubmit}
			>
				<SendHorizonal class="size-4" />
			</Button>
		{/if}
	</div>
</section>
