<script lang="ts">
	import { IS_DESKTOP } from '$lib/utils/constants';
	import {
		showNav,
		innerWidthStore,
		innerHeightStore,
		currentAlphabet,
		searchKanji,
		currentFlashcard,
		selectedQuizItems
	} from '$lib/utils/stores';
	import { ArrowLeft, Search } from 'lucide-svelte';

	$: $innerWidthStore > IS_DESKTOP && ($showNav = false);

	function handleInput(e: Event) {
		const target = e.target as HTMLInputElement;
		if (target.value.length > 1) target.value = target.value.slice(0, 1);
	}
</script>

<svelte:window bind:innerWidth={$innerWidthStore} bind:innerHeight={$innerHeightStore} />

<main class="relative flex h-[100dvh] select-none flex-col items-center p-2 sm:px-3 sm:py-5">
	<nav class="relative flex w-full justify-between px-2 py-3 xm:p-5">
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
			<span>Back</span>
		</a>

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
