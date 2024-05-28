<script lang="ts">
	import { browser } from '$app/environment';
	if (browser) window.process = { env: { IS_PREACT: false } };

	import type { ExcalidrawImperativeAPI } from '@excalidraw/excalidraw/types/types.js';
	let excalidrawAPI: ExcalidrawImperativeAPI;
</script>

{#if browser}
	{#await import('./Excalidraw.svelte')}
		Loading Excalidraw...
	{:then { default: Excalidraw }}
		<svelte:component this={Excalidraw} bind:excalidrawAPI />
	{/await}
{:else}
	Not browser
{/if}
