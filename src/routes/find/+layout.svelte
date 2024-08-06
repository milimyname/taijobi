<script lang="ts">
	import { ArrowLeft } from 'lucide-svelte';
</script>

<svelte:head>
	<title>Find Kanji</title>
	<meta name="Find Kanji" content="Find Kanji" />
</svelte:head>

<main class="flex h-dvh flex-col items-center bg-white transition-all">
	<nav class="flex w-full items-center justify-between p-5">
		<a href="/" class="go-back-btn group flex items-center gap-2" data-sveltekit-preload-data>
			<ArrowLeft
				class="size-4 transition-transform  group-hover:-translate-x-2  group-active:-translate-x-2 "
			/>
		</a>
	</nav>

	<slot />
</main>
