<script lang="ts">
	import '../app.css';
	import FeedbackForm from '$lib/components/forms/feedback-form-ui.svelte';
	import Umami from '$lib/components/Umami.svelte';
	import { innerWidthStore, innerHeightStore, strokes, openSearch } from '$lib/utils/stores';
	import Search from '$lib/components/Search.svelte';
	import { Toaster } from '$lib/components/ui/sonner';
	import Kbd from '$lib/components/Kbd.svelte';
	import { afterNavigate, onNavigate } from '$app/navigation';
	import { navigating } from '$app/stores';
	import { LoaderCircle } from 'lucide-svelte';
	import { onMount } from 'svelte';

	let showLoader = false;
	let navigationTimer: NodeJS.Timeout;

	$: if ($navigating) {
		navigationTimer = setTimeout(() => {
			showLoader = true;
		}, 2000);
	} else {
		if (navigationTimer) clearTimeout(navigationTimer);
		showLoader = false;
	}

	// Clear strokes on navigation
	afterNavigate(() => {
		$strokes = [];
		$openSearch = false;
	});

	onMount(() => {
		return () => {
			if (navigationTimer) clearTimeout(navigationTimer);
		};
	});

	onNavigate((navigation) => {
		if (!document.startViewTransition) return;

		return new Promise((resolve) => {
			document.startViewTransition(async () => {
				resolve();
				await navigation.complete;
			});
		});
	});
</script>

<svelte:window bind:innerWidth={$innerWidthStore} bind:innerHeight={$innerHeightStore} />

<Umami />
<FeedbackForm />
<Search />
<Toaster />
<Kbd />

{#if showLoader}
	<LoaderCircle
		class="fixed left-1/2 top-1/2 size-20 -translate-x-1/2 -translate-y-1/2 transform"
	/>
	<div class="fixed inset-0 z-10 bg-background/80 backdrop-blur-sm" />
{/if}

<slot />
