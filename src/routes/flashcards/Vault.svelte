<script lang="ts">
	import { clickedAddFlashcard, clickedFlashCard } from '$lib/utils/stores';
	import { quintOut } from 'svelte/easing';
	import { fly } from 'svelte/transition';

	export let enhance;
</script>

{#if $clickedFlashCard || $clickedAddFlashcard}
	<div class="fixed top-0 z-[100] h-screen w-full bg-black opacity-50 transition-all" />
{/if}

{#if $clickedAddFlashcard}
	<form
		use:enhance
		method="POST"
		class="add-collection-btn fixed -bottom-5 z-[101] flex h-1/2 w-full flex-col gap-5 overflow-hidden rounded-t-2xl bg-white px-5 py-10 sm:bottom-0"
		transition:fly={{
			delay: 0,
			duration: 1000,
			opacity: 0,
			y: 600,
			easing: quintOut
		}}
	>
		<slot />
	</form>
{/if}
