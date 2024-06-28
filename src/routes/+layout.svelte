<script lang="ts">
	import '../app.css';
	import FeedbackForm from '$lib/components/forms/feedback-form-ui.svelte';
	import Umami from '$lib/components/Umami.svelte';
	import { innerWidthStore, innerHeightStore, strokes, openSearch } from '$lib/utils/stores';
	import Search from '$lib/components/Search.svelte';
	import { Toaster } from '$lib/components/ui/sonner';
	import Kbd from '$lib/components/Kbd.svelte';
	import { afterNavigate } from '$app/navigation';

	// Clear strokes on navigation
	afterNavigate(() => {
		$strokes = [];
		$openSearch = false;
	});
</script>

<svelte:window bind:innerWidth={$innerWidthStore} bind:innerHeight={$innerHeightStore} />

<Umami />
<FeedbackForm />
<Search />
<Toaster />
<Kbd />

<slot />
