<script lang="ts">
	import { Button } from '$lib/components/ui/button';
	import { ArrowLeft } from 'lucide-svelte';
</script>

<svelte:head>
	<title>Feedbacks</title>
	<meta name="Feedbacks" content="Feedbacks" />
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
