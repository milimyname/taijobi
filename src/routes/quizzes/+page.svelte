<script lang="ts">
	import { browser } from '$app/environment';
	import { goto, invalidateAll } from '$app/navigation';
	import { pocketbase } from '$lib/utils/pocketbase.js';

	export let data;
</script>

<section class="flex w-full max-w-xl flex-col gap-2 overflow-y-scroll not-last:border-b">
	{#each data.quizzes as quiz}
		{@const anyProgress = browser && localStorage.getItem(`quizProgress_${quiz.id}`)}
		<div class="flex w-full flex-col justify-center gap-4 p-4">
			<div class="flex w-full justify-between">
				<h4 class="text-xl font-medium">Quiz: {quiz.name}</h4>
				<div class="flex gap-2">
					<span class="text-sm">Type: {quiz.type}</span>
					<span class="line-clamp-3 text-left text-sm">Count: {quiz.maxCount}</span>
				</div>
			</div>
			<div class="flex justify-between">
				<button
					class="self-center rounded-full font-bold"
					on:click={() => {
						localStorage.removeItem(`flashcards_${quiz.id}`);
						localStorage.removeItem(`currentQuestion_${quiz.id}`);
						localStorage.removeItem(`quizProgress_${quiz.id}`);
						goto(`/quizzes/${quiz.id}`);
					}}
				>
					Restart
				</button>
				{#if anyProgress}
					<button
						class="self-center rounded-full font-bold"
						on:click={() => goto(`/quizzes/${quiz.id}`)}
					>
						Continue from {JSON.parse(anyProgress).length}
					</button>
				{/if}

				{#if quiz.id !== 'hiragana' && quiz.id !== 'katakana'}
					<button
						class="self-center rounded-full font-bold text-red-600"
						on:click|preventDefault={async () => {
							localStorage.removeItem(`flashcards_${quiz.id}`);
							localStorage.removeItem(`currentQuestion_${quiz.id}`);
							localStorage.removeItem(`quizProgress_${quiz.id}`);

							await pocketbase.collection('quizzes').delete(quiz.id);

							invalidateAll();
						}}
					>
						Delete
					</button>
				{/if}
			</div>
		</div>
	{/each}
</section>
