<script lang="ts">
	import { page } from '$app/stores';
	import { ArrowLeft } from 'lucide-svelte';
</script>

<svelte:head>
	<title>Quizzes</title>
	<meta name="description" content="Quizzes" />
	<meta name="theme-color" content="rgb(0,0,0)" />
</svelte:head>

<main class="flex h-[100dvh] select-none flex-col items-center overflow-hidden bg-white px-3 py-5">
	<nav class="flex w-full p-5">
		<a
			href={$page.route.id && $page.route.id.length < 12 ? '/' : '/quizzes'}
			class="group flex items-center gap-2"
			data-sveltekit-preload-data
		>
			<ArrowLeft
				class="h-4 w-4 transition-transform group-hover:-translate-x-2 group-active:-translate-x-2"
			/>
			<span>Back</span>
		</a>
	</nav>

	<slot />
</main>
