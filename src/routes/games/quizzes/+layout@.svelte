<script lang="ts">
	import { page } from '$app/stores';
	import { ArrowLeft } from 'lucide-svelte';
	import { Button } from '$lib/components/ui/button';
</script>

<svelte:head>
	<title>Quizzes</title>
	<meta name="description" content="Quizzes" />
</svelte:head>

<main class="flex h-dvh flex-col items-center bg-white transition-all">
	<nav class="flex w-full p-2 py-3 sm:px-3 sm:py-5">
		<Button size="icon" variant="none">
			<a
				href={$page.params.slug ? '/games/quizzes' : '/'}
				class="go-back-btn group"
				data-sveltekit-preload-data
			>
				<ArrowLeft
					class="size-4 transition-transform  group-hover:-translate-x-2 group-active:-translate-x-2"
				/>
			</a>
		</Button>
	</nav>
	<slot />
</main>
