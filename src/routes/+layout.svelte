<script lang="ts">
	import '../app.css';
	import Loading from '$lib/components/loading.svelte';
	import FeedbackForm from '$lib/components/forms/feedback-form-ui.svelte';
	import Umami from '$lib/components/Umami.svelte';
	import {
		innerWidthStore,
		innerHeightStore,
		strokes,
		openSearch,
		loading,
	} from '$lib/utils/stores';
	import Search from '$lib/components/Search.svelte';
	import { Toaster } from '$lib/components/ui/sonner';
	import Helper from '$lib/components/Helper.svelte';
	import { afterNavigate, onNavigate } from '$app/navigation';
	import { onMount } from 'svelte';
	import { isDesktop } from '$lib/utils';

	// Clear strokes on navigation
	afterNavigate(() => {
		$strokes = [];
		$openSearch = false;
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

	onMount(() => {
		// Show eruda in development mode on mobile
		if (import.meta.env.MODE === 'development' && !$isDesktop)
			import('eruda').then((eruda) => eruda.default.init());

		// Prevent user from reloading the page while something is loading
		window.addEventListener('beforeunload', (event) => {
			if ($loading) event.preventDefault();
		});
	});
</script>

<svelte:head>
	<title>Taijobi</title>
	<meta name="Taijobi" content="Taijobi" />
</svelte:head>

<svelte:window bind:innerWidth={$innerWidthStore} bind:innerHeight={$innerHeightStore} />

<Umami />
<Toaster />
<Search />

<Loading>
	<Helper />
	<FeedbackForm />
	<slot />
</Loading>
