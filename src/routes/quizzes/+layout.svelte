<script lang="ts">
	import { goto } from '$app/navigation';
	import { page } from '$app/stores';
	import { ArrowLeft } from 'lucide-svelte';
</script>

<svelte:head>
	<title>Quizzes</title>
	<meta name="description" content="Quizzes" />
	<meta name="theme-color" content="rgb(0,0,0)" />
</svelte:head>

<main class="flex h-[100dvh] select-none flex-col items-center overflow-hidden bg-white px-3 py-5">
	<nav class="z-[99] flex w-full p-5">
		<button
			on:click|preventDefault={() =>
				$page.route.id && goto($page.route.id.length < 12 ? '/' : '/quizzes')}
			class="flex items-center gap-2"
		>
			<ArrowLeft class="h-5 w-5" />
			<span>Back</span>
		</button>
	</nav>

	<slot />
</main>
