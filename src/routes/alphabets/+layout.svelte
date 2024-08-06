<script lang="ts">
	import { IS_DESKTOP } from '$lib/utils/constants';
	import {
		showNav,
		innerWidthStore,
		currentAlphabet,
		searchKanji,
		currentFlashcard,
		selectedQuizItems,
	} from '$lib/utils/stores';
	import { ArrowLeft, Search } from 'lucide-svelte';
	import { Button } from '$lib/components/ui/button';

	$: $innerWidthStore > IS_DESKTOP && ($showNav = false);

	function handleInput(e: Event) {
		const target = e.target as HTMLInputElement;
		if (target.value.length > 1) target.value = target.value.slice(0, 1);
	}
</script>

<main class="flex h-dvh flex-col items-center bg-white p-2 transition-all sm:px-3 sm:py-5">
	<nav class="relative flex w-full items-center justify-between p-5">
		<Button size="icon" variant="none">
			<a
				href="/"
				class="go-back-btn group group flex items-center gap-2"
				on:click={() => {
					$currentFlashcard = '';
					$selectedQuizItems = [];
				}}
			>
				<ArrowLeft
					class="size-4 transition-transform group-hover:-translate-x-2 group-active:-translate-x-2"
				/>
			</a>
		</Button>

		{#if $currentAlphabet === 'kanji'}
			<div class="kanji-search flex flex-row-reverse">
				<label for="search" class="my-auto">
					<Search class="size-5" />
				</label>
				<input
					type="text"
					id="search"
					bind:value={$searchKanji}
					on:input={handleInput}
					autocomplete="off"
					class="w-4 border-hidden bg-transparent outline-none focus:border-transparent focus:bg-transparent focus:ring-0 focus:ring-transparent"
				/>
			</div>
		{/if}
	</nav>

	<slot />
</main>
