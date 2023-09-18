<script lang="ts">
	import { clickedQuizForm } from '$lib/utils/stores';
	import { fly, slide } from 'svelte/transition';
	import { quintOut } from 'svelte/easing';

	export let enhance: boolean;
	export let errors;
	export let form;
	export let constraints;
</script>

{#if $clickedQuizForm}
	<form
		use:enhance
		method="POST"
		class="quiz-form fixed -bottom-5 z-[1000] flex h-1/2 w-full flex-col gap-5 overflow-hidden rounded-t-2xl bg-white px-5 py-10 sm:bottom-0"
		transition:fly={{
			delay: 0,
			duration: 1000,
			opacity: 0,
			y: 1000,
			easing: quintOut
		}}
	>
		<h4 class="text-2xl">Create a {$form.name} quiz</h4>
		<h5>Work in progress</h5>
	</form>
{/if}
