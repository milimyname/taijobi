<script lang="ts">
	import { Button } from '$lib/components/ui/button';
	import { ArrowLeft, Settings } from 'lucide-svelte';
	import { openHistory, paragraphs } from '$lib/utils/stores';
	import ParagraphsDrawerDialog from './paragraphs-drawer-dialog.svelte';

	export let data;

	$: $paragraphs = data.paragraphs;
</script>

<svelte:head>
	<title>Paragraphs</title>
	<meta name="paragraphs" content="Paragraphs" />
</svelte:head>

<ParagraphsDrawerDialog />

<main class="flex h-dvh flex-col items-center bg-white transition-all">
	<nav class="flex w-full items-center justify-between p-5 sm:py-5">
		<Button size="icon" variant="none">
			<a href="/" class="go-back-btn group" data-sveltekit-preload-data>
				<ArrowLeft
					class="size-5 transition-transform  group-hover:-translate-x-2 group-active:-translate-x-2"
				/>
			</a>
		</Button>

		<Button
			size="icon"
			variant="none"
			disabled={$paragraphs.length === 0}
			on:click={() => ($openHistory = true)}
		>
			<Settings class="size-5" />
		</Button>
	</nav>

	<slot />
</main>
