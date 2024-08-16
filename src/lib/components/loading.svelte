<script lang="ts">
	import { onMount } from 'svelte';
	import { scale } from 'svelte/transition';
	import { elasticIn } from 'svelte/easing';

	let isLoading = true;

	onMount(async () => {
		// Simulate data fetching
		await new Promise((resolve) => setTimeout(resolve, 100));
		isLoading = false;
	});
</script>

{#if isLoading}
	<div class="fixed left-1/2 top-1/2 z-[9999] -translate-x-1/2 -translate-y-1/2">
		<img
			src="/taijobi.png"
			class="size-40 animate-ping rounded-full shadow-logo sm:h-12 sm:w-12"
			alt="Logo"
			transition:scale={{
				duration: 50,
				delay: 0,
				opacity: 0.5,
				start: 0.8,
				easing: elasticIn,
			}}
		/>
	</div>
{:else}
	<slot />
{/if}
