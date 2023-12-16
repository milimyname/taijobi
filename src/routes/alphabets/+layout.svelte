<script lang="ts">
	import ProgressSlider from './ProgressSlider.svelte';
	import { twSmallScreen } from '$lib/utils/constants';
	import {
		showNav,
		innerWidthStore,
		innerHeightStore,
		currentAlphabet,
		searchKanji,
		currentFlashcard
	} from '$lib/utils/stores';
	import DrawingNav from '$lib/components/DrawingNav.svelte';
	import { ArrowLeft, Search } from 'lucide-svelte';

	$: $innerWidthStore > twSmallScreen && ($showNav = false);

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
			on:click={() => ($currentFlashcard = '')}
		>
			<ArrowLeft
				class="h-4 w-4 transition-transform group-hover:-translate-x-2 group-active:-translate-x-2"
			/>
			<span>Back</span>
		</a>

		{#if $currentAlphabet === 'kanji'}
			<div class="kanji-search">
				<label for="search">
					<Search class="absolute right-2 top-5 h-5 w-5 xm:right-5 xm:top-7" />
				</label>
				<input
					type="text"
					id="search"
					bind:value={$searchKanji}
					on:input={handleInput}
					autocomplete="off"
					class="w-14 border-hidden bg-white outline-none focus:border-transparent focus:bg-transparent focus:ring-0 focus:ring-transparent"
				/>
			</div>
		{/if}
	</nav>

	<DrawingNav />
	<ProgressSlider />
	<slot />
</main>
