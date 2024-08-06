<script lang="ts">
	import {
		currentLetter,
		currentAlphabet,
		innerWidthStore,
		innerHeightStore,
		clickedQuizForm,
		clickedKanjiForm,
		showProgressSlider,
	} from '$lib/utils/stores';
	import { toRomaji } from 'wanakana';
	import { kanji } from '$lib/static/kanji';
	import { Dices } from 'lucide-svelte';
	import { page } from '$app/stores';
	import { getFlashcardHeight, getFlashcardWidth } from '$lib/utils';
	import { goto } from '$app/navigation';
	import { browser } from '$app/environment';
	import { replaceStateWithQuery } from '$lib/utils';

	export let rotateYCard: number;

	$: if (
		browser &&
		$currentAlphabet === 'kanji' &&
		$page.url.pathname.includes('alphabet') &&
		!$showProgressSlider
	)
		replaceStateWithQuery({
			letter: $currentLetter,
			meaning: kanji[$currentLetter].meaning,
			onyomi: kanji[$currentLetter].onyomi.join(', '),
			kunyomi: kanji[$currentLetter].kunyomi.join(', '),
		});
	else if (
		browser &&
		$currentAlphabet !== 'kanji' &&
		$page.url.pathname.includes('alphabet') &&
		!$showProgressSlider
	)
		replaceStateWithQuery({
			letter: $currentLetter,
			romaji: toRomaji($currentLetter),
		});
</script>

<div
	style={`transform: rotateY(${180 - rotateYCard}deg); backface-visibility: hidden; 
			height: ${getFlashcardHeight($innerWidthStore, $innerHeightStore)}px;
			width: ${getFlashcardWidth($innerWidthStore)}px `}
	class="alphabet relative z-10 mx-auto
				{rotateYCard > 90 ? 'block' : 'hidden'} 
				 flex flex-col
				 {$currentAlphabet === 'kanji' ? 'gap-1' : ' gap-2 sm:gap-5'}
				 justify-center overflow-hidden rounded-xl border p-3 shadow-sm xm:p-5 sm:p-10"
>
	<div
		class="grid-rows-[max-content max-content] xm:grid-rows-[max-content 1fr] grid h-full grid-cols-2 xm:grid-cols-none xm:gap-4"
	>
		{#if $currentAlphabet === 'kanji' && kanji[$currentLetter]}
			<h2 class="col-span-2 text-center text-6xl xm:text-9xl">{$currentLetter}</h2>
			<div>
				<h2 class="text-lg font-medium">{kanji[$currentLetter].meaning}</h2>
				<p class=" text-sm text-gray-300 sm:text-sm">Meaning</p>
			</div>
			{#if kanji[$currentLetter].onyomi.length > 0}
				<div>
					<h4 class="text-lg tracking-widest">{kanji[$currentLetter].onyomi}</h4>
					<p class=" text-sm text-gray-300">Onyomi</p>
				</div>
			{/if}
			{#if kanji[$currentLetter].kunyomi.length > 0}
				<div>
					<h4 class="text-lg tracking-widest">{kanji[$currentLetter].kunyomi}</h4>
					<p class="text-sm text-gray-300">Kunyomi</p>
				</div>
			{/if}

			{#if $page.url.pathname.includes('alphabet')}
				<button
					class="fixed bottom-3 left-3 z-30 rounded-full border bg-white p-2 shadow-sm transition-all sm:bottom-5 sm:left-5"
					on:click={() => {
						if (!$page.data.isLoggedIn) return goto('/login');

						$clickedQuizForm = true;
						$clickedKanjiForm = true;
					}}
				>
					<Dices class="size-4" />
				</button>
			{/if}
		{:else}
			<h2 class="col-span-2 text-center text-6xl xm:text-9xl">{$currentLetter}</h2>
			<div>
				<h2 class="text-lg font-medium">{toRomaji($currentLetter)}</h2>
				<p class=" text-sm text-gray-300 sm:text-sm">Romaji</p>
			</div>
		{/if}
	</div>
</div>
