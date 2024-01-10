<script>
	import { dev } from '$app/environment';
</script>

<svelte:head>
	{#if !dev}
		<script
			async
			src="https://analytics.taijobi.com/script.js"
			data-website-id="51bced60-cf6d-46e0-b27c-0b7dfd457aba"
		></script>
	{/if}
</svelte:head>
