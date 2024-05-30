<script lang="ts">
	import { page } from '$app/stores';
	import { ArrowLeft } from 'lucide-svelte';
</script>

<svelte:head>
	<title>Quizzes</title>
	<meta name="description" content="Quizzes" />
</svelte:head>

<main
	class="flex min-h-screen select-none flex-col items-center overflow-hidden bg-white px-3 py-5"
>
	<nav class="flex w-full py-5 md:px-5">
		<a
			href={$page.params.slug ? '/games/quizzes' : '/games'}
			class="group flex items-center gap-2"
			data-sveltekit-preload-data
		>
			<ArrowLeft
				class="size-4 transition-transform group-hover:-translate-x-2 group-active:-translate-x-2"
			/>
			<span>Back</span>
		</a>
	</nav>

	<slot />
</main>
