<script lang="ts">
	import { goto } from '$app/navigation';
	import { page } from '$app/stores';
	import { Dices, Pencil } from 'lucide-svelte';
	import { onMount } from 'svelte';

	let callback: string = '/';

	onMount(async () => {
		const urlParams = new URLSearchParams($page.url.search);
		callback = decodeURIComponent(urlParams.get('callback') || '/');
	});
</script>

{#if callback !== '/'}
	<button
		class="mr-2 flex items-center gap-2 rounded-full border px-4 py-2"
		on:click={() => goto(callback)}
	>
		{#if callback.includes('quizzes')}
			<Dices class="size-5" />
			<span>Return to Quiz</span>
		{:else}
			<Pencil class="size-5" />
			<span>Return to Find Word</span>
		{/if}
	</button>
{/if}
