<script lang="ts">
	import { clickedAddFlashcard, clickedFlashCard } from '$lib/utils/stores';
	import { quintOut } from 'svelte/easing';
	import { fly } from 'svelte/transition';

	export let enhance;
	export let notes = false;
</script>

{#if $clickedFlashCard || $clickedAddFlashcard}
	<div class="fixed top-0 z-[100] h-screen w-full bg-black opacity-50 transition-all" />
{/if}

{#if $clickedAddFlashcard}
	<form
		use:enhance
		method="POST"
		class="add-form-btn fixed -bottom-5 z-[1000] flex {notes
			? 'h-[75%]'
			: 'h-1/2'} w-full flex-col gap-5 overflow-hidden rounded-t-2xl bg-white px-5 py-10 sm:bottom-0 md:max-w-4xl"
		transition:fly={{
			delay: 0,
			duration: 1000,
			opacity: 0,
			y: 1000,
			easing: quintOut
		}}
	>
		<slot />
	</form>
{/if}
