<script>
	import { Input } from '$lib/components/ui/input';
	import { Button } from '$lib/components/ui/button';
	import { useChat } from '@ai-sdk/svelte';
	import { toast } from 'svelte-sonner';
	import { goto } from '$app/navigation';

	const { input, handleSubmit, messages } = useChat({
		api: '/api/openai/chat',
		onFinish(message) {
			if (message.toolInvocations) {
				const searchId = message.toolInvocations[0]?.result?.searches[0];

				if (!searchId) return;

				toast('Redict to the search page?', {
					action: {
						label: 'Yes',
						onClick: () => {
							goto('/search/' + searchId);
						},
					},
				});
			}
		},
	});
</script>

<div class="space-y-4 h-[80dvh] w-full pt-5">
	<ul class="border rounded-md p-2 w-full h-full overflow-scroll">
		{#each $messages as message}
			<li>{message.role}: {message.content}</li>
		{/each}
	</ul>
	<form on:submit={handleSubmit} class="flex gap-2">
		<Input bind:value={$input} />
		<Button type="submit">Send</Button>
	</form>
</div>
