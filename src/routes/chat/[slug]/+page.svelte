<script lang="ts">
	import { Button } from '$lib/components/ui/button';
	import { useChat } from '@ai-sdk/svelte';
	import { toast } from 'svelte-sonner';
	import { goto } from '$app/navigation';
	import { Textarea } from '$lib/components/ui/textarea';
	import { SendHorizonal } from 'lucide-svelte';
	import { onMount } from 'svelte';
	import { page } from '$app/stores';
	import { pocketbase } from '$lib/utils/pocketbase';
	import { chats } from '$lib/utils/stores.js';

	export let data;

	const chatID = $page.params.slug;

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

			const newMessages = await Promise.all(
				$messages.slice(-2).map((message) =>
					pocketbase.collection('messages').create(
						{
							content: message.content,
							role: message.role,
							user: $page.data.user.id,
							chat: chatID,
						},
						{
							requestKey: null,
						},
					),
				),
			);

			// Update the chat with the latest message
			await pocketbase.collection('chats').update(chatID, {
				'messages+': newMessages.map((message) => message.id),
			});

			// Update the chat in the store
			$chats = $chats.map((chat) => {
				if (chat.id === chatID) {
					return {
						...chat,
						messages: [...chat.messages, ...newMessages],
					};
				}
				return chat;
			});
		},
	});

	onMount(() => {
		const textarea = document.querySelector('textarea');
		if (textarea) {
			textarea.addEventListener('keydown', (event) => {
				if (event.key === 'Enter' && !event.shiftKey) {
					event.preventDefault();
					handleSubmit(event);
				}
			});
		}
	});

	// Update the height of the textarea based on the input content
	$: if (typeof window !== 'undefined' && $input) {
		const textarea = document.querySelector('textarea');
		if (textarea) {
			textarea.style.height = (textarea.scrollHeight > 40 ? textarea.scrollHeight : 40) + 'px';
		}
	}

	$: if (typeof window !== 'undefined' && $input === '') {
		const textarea = document.querySelector('textarea');
		if (textarea) textarea.style.height = '40px';
	}

	$: chatMessages = [...data?.messages, ...$messages];
</script>

<section class="size-full space-y-4 overflow-auto pt-5">
	<ul class="size-full px-5 md:mx-auto md:max-w-xl">
		{#each chatMessages as message}
			<li>
				<span class="font-bold">{message.role}:</span>
				{#if message.role === 'assistant'}
					{@html message.content}
				{:else}
					{message.content}
				{/if}
			</li>
		{/each}
		<div class="invisible h-20 opacity-0" />
	</ul>
	<form
		on:submit={handleSubmit}
		class="fixed bottom-5 flex w-full items-center justify-center gap-2 px-5"
	>
		<div class="relative flex w-full items-end md:w-[36rem]">
			<Textarea class="h-10 max-h-40 min-h-fit resize-none pr-10" bind:value={$input} />
			<Button
				type="submit"
				disabled={!$input.trim() || $isLoading}
				size="icon"
				variant="outline"
				class="absolute bottom-1.5 right-2 mt-auto size-7"
			>
				<SendHorizonal class="size-4" />
			</Button>
		</div>
	</form>
</section>
