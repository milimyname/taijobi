<script lang="ts">
	import { page } from '$app/stores';
	import { ArrowLeft } from 'lucide-svelte';
	import { Button } from '$lib/components/ui/button';
</script>

<svelte:head>
	<title>Quizzes</title>
	<meta name="description" content="Quizzes" />
</svelte:head>

<main class="flex h-dvh flex-col items-center bg-white p-2 transition-all sm:px-3 sm:py-5">
	<nav class="flex w-full items-center p-5">
		<Button size="icon" variant="none">
			<a
				href={$page.params.slug ? '/games/conjugate' : '/games'}
				class="group flex items-center gap-2"
				data-sveltekit-preload-data
			>
				<ArrowLeft
					class="size-5 transition-transform group-hover:-translate-x-2 group-active:-translate-x-2"
				/>
			</a>
		</Button>
	</nav>

	<slot />
</main>
