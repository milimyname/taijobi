<script lang="ts">
	import { Button } from '$lib/components/ui/button';
	import { useChat } from '@ai-sdk/svelte';
	import { toast } from 'svelte-sonner';
	import { goto } from '$app/navigation';
	import { Textarea } from '$lib/components/ui/textarea';
	import { SendHorizonal } from 'lucide-svelte';
	import { onMount } from 'svelte';
	import { pocketbase } from '$lib/utils/pocketbase';
	import { page } from '$app/stores';
	import { chats } from '$lib/utils/stores';
	import { browser } from '$app/environment';

	let textArea: HTMLTextAreaElement;

	const { input, handleSubmit, messages, isLoading } = useChat({
		api: '/api/openai/chat',
		async onFinish(message) {
			if (message.toolInvocations) {
				const searchId = message.toolInvocations[0]?.result?.searches[0];

				if (!searchId) return;

				toast('Go to the search page?', {
					action: {
						label: 'Yes',
						onClick: () => {
							goto('/search/' + searchId);
						},
					},
				});
			}

			// Create a chat record
			let chat = await pocketbase.collection('chats').create({
				user: $page.data.user.id,
			});

			const newMessages = await Promise.all(
				$messages.map((message) =>
					pocketbase.collection('messages').create(
						{
							content: message.content,
							role: message.role,
							user: $page.data.user.id,
							chat: chat.id,
						},
						{
							requestKey: null,
						},
					),
				),
			);

			// Update the chat with the latest message
			chat = await pocketbase.collection('chats').update(chat.id, {
				messages: newMessages.map((message) => message.id),
			});

			$chats = [...$chats, chat];

			setTimeout(() => {
				goto('/chat/' + chat.id);
			}, 250);
		},
	});

	onMount(() => {
		textArea = document.querySelector('textarea') as HTMLTextAreaElement;
	});

	$: if (browser && $input && textArea)
		textArea.style.height = (textArea.scrollHeight > 50 ? textArea.scrollHeight - 10 : 40) + 'px';

	$: if (browser && $input === '' && textArea) textArea.style.height = '40px';
</script>

<section class="size-full space-y-4 pt-5">
	<ul class="size-full overflow-auto px-5 pb-20 md:mx-auto md:max-w-xl">
		{#each $messages as message}
			<li>
				{message.role}:
				{#if message.role === 'assistant'}
					{@html message.content}
				{:else}
					{message.content}
				{/if}
			</li>
		{/each}

		{#if $messages.length === 0}
			<p class="mt-40 text-balance text-center text-gray-500">
				No messages yet. Please type something below
			</p>
		{/if}
	</ul>
	<form
		on:submit={handleSubmit}
		class="fixed bottom-5 flex w-full items-center justify-center gap-2 px-5"
	>
		<div class="relative flex w-full items-end md:w-[36rem]">
			<Textarea class="h-10 max-h-40 min-h-0 resize-none pr-10 shadow-sm" bind:value={$input} />
			<Button
				type="submit"
				disabled={!$input.trim() || $isLoading}
				loading={$isLoading}
				size="icon"
				variant="outline"
				class="absolute bottom-1.5 right-2 mt-auto size-7"
			>
				<SendHorizonal class="size-4" />
			</Button>
		</div>
	</form>
</section>
