<script lang="ts">
	import '../app.css';
	import FeedbackForm from '$lib/components/forms/feedback-form-ui.svelte';
	import Umami from '$lib/components/Umami.svelte';
	import { innerWidthStore, innerHeightStore } from '$lib/utils/stores';
	import Search from '$lib/components/Search.svelte';
	import { Toaster } from '$lib/components/ui/sonner';
	import Kbd from '$lib/components/Kbd.svelte';
</script>

<svelte:window bind:innerWidth={$innerWidthStore} bind:innerHeight={$innerHeightStore} />

<Umami />
<FeedbackForm />
<Search />
<Toaster />
<Kbd />

<slot />
