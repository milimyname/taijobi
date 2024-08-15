<script lang="ts">
	import { ArrowLeft } from 'lucide-svelte';
	import { Button } from '$lib/components/ui/button';
	import { page } from '$app/stores';
	import { goto } from '$app/navigation';
</script>

<svelte:head>
	<title>Quizzes</title>
	<meta name="Quizzes" content="Quizzes" />
</svelte:head>

<main class="flex h-dvh flex-col items-center bg-white transition-all">
	<nav class="flex w-full items-center p-5">
		<Button
			size="icon"
			variant="none"
			on:click={() => {
				goto($page.route.id && $page.route.id.length > 15 ? '/games/quizzes' : '/');
			}}
		>
			<div class="go-back-btn group" data-sveltekit-preload-data>
				<ArrowLeft
					class="size-5 transition-transform  group-hover:-translate-x-2 group-active:-translate-x-2"
				/>
			</div>
		</Button>
	</nav>
	<slot />
</main>
