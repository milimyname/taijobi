<script lang="ts">
	import { ArrowLeft } from 'lucide-svelte';
	import { Button } from '$lib/components/ui/button';
</script>

<svelte:head>
	<title>Search Word</title>
	<meta name="description" content="Find a japanese word in Taijobi" />
</svelte:head>

<main class="flex h-dvh flex-col items-center bg-white p-2 transition-all sm:px-3 sm:py-5">
	<nav class="flex w-full items-center justify-between p-5">
		<Button size="icon" variant="none">
			<a href="/" class="go-back-btn group" data-sveltekit-preload-data>
				<ArrowLeft
					class="size-5 transition-transform  group-hover:-translate-x-2 group-active:-translate-x-2"
				/>
			</a>
		</Button>
	</nav>

	<slot />
</main>
