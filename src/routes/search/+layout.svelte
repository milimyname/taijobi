<script lang="ts">
	import { searchedWordStore } from '$lib/utils/stores';
	import { ArrowLeft } from 'lucide-svelte';
</script>

<svelte:head>
	<title>Search Word</title>
	<meta name="description" content="Find a japanese word in Taijobi" />
</svelte:head>

<main
	class="flex h-dvh flex-col items-center overflow-hidden bg-white p-2 transition-all sm:px-3 sm:py-5"
>
	<nav class="flex w-full justify-between px-2 py-3 xm:p-5">
		<a
			href="/"
			class="go-back-btn group flex items-center gap-2"
			on:click={() => ($searchedWordStore = {})}
			data-sveltekit-preload-data
		>
			<ArrowLeft
				class="size-4 transition-transform  group-hover:-translate-x-2  group-active:-translate-x-2 "
			/>
			<span>Back</span>
		</a>
	</nav>

	<slot />
</main>
