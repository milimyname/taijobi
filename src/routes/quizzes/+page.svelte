<script lang="ts">
	import { browser } from '$app/environment';
	import { goto } from '$app/navigation';

	export let data;
</script>

<section class="flex w-full flex-col gap-2 not-last:border-b">
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
						on:click={() => {
							// localStorage.removeItem(`flashcards_${quiz.id}`);
							goto(`/quizzes/${quiz.id}`);
						}}
					>
						Continue from {JSON.parse(anyProgress).length}
					</button>
				{/if}
			</div>
		</div>
	{/each}
</section>
