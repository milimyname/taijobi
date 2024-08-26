<script lang="ts">
	import { goto } from '$app/navigation';
	import { page } from '$app/stores';
	import { cn } from '$lib/utils';
	import { Dices, Pencil } from 'lucide-svelte';
	import { onMount } from 'svelte';
	import * as Tooltip from '$lib/components/ui/tooltip';

	let callback: string = '/';

	onMount(() => {
		const urlParams = new URLSearchParams($page.url.search);
		callback = decodeURIComponent(urlParams.get('callback') || '/');
	});
</script>

{#if callback !== '/'}
	<Tooltip.Root open={callback !== '/'}>
		<Tooltip.Trigger class="flex items-center">
			<button
				on:click={() => goto(callback)}
				class={cn(
					!callback.includes('quizzes') &&
						'mr-2 flex items-center gap-2 rounded-full border px-4 py-2',
				)}
			>
				{#if callback.includes('quizzes')}
					<Dices class="size-5" />
				{:else}
					<Pencil class="size-5" />
					<span>Return</span>
				{/if}
			</button>
		</Tooltip.Trigger>
		<Tooltip.Content>
			<p>Go back {callback.includes('quizzes') ? 'to quizzes' : 'to previous page'}</p>
		</Tooltip.Content>
	</Tooltip.Root>
{/if}
