<script lang="ts">
	import { Button } from '$lib/components/ui/button';
	import { ArrowLeft, Settings } from 'lucide-svelte';
	import ChatDrawerDialog from './chat-drawer-dialog.svelte';
	import { openHistory, chats } from '$lib/utils/stores';

	export let data;

	$: $chats = data.chats;
</script>

<svelte:head>
	<title>Chat</title>
	<meta name="Chat" content="Chat" />
</svelte:head>

<ChatDrawerDialog />

<main class="flex h-dvh flex-col items-center bg-white transition-all">
	<nav class="mb-auto flex w-full items-center justify-between p-5 sm:py-5">
		<Button size="icon" variant="none">
			<a href="/" class="go-back-btn group" data-sveltekit-preload-data>
				<ArrowLeft
					class="size-5 transition-transform  group-hover:-translate-x-2 group-active:-translate-x-2"
				/>
			</a>
		</Button>

		<Button
			size="icon"
			variant="none"
			disabled={$chats.length === 0}
			on:click={() => ($openHistory = true)}
		>
			<Settings class="size-5" />
		</Button>
	</nav>
	<slot />
</main>
