<script lang="ts">
	import '../app.css';
	import FeedbackForm from '$lib/components/forms/feedback-form-ui.svelte';
	import Umami from '$lib/components/Umami.svelte';
	import { clickedFeedback } from '$lib/utils/stores';
	import { isDesktop } from '$lib/utils';
</script>

<Umami />
<FeedbackForm />

{#if $clickedFeedback && !$isDesktop}
	<div data-vaul-drawer-wrapper class={'min-h-dvh bg-white'}>
		<slot />
	</div>
{:else}
	<slot />
{/if}
