<script lang="ts">
	import { isDesktop } from '$lib/utils';
	import { DialogContent } from '$lib/components/ui/dialog';
	import { DrawerContent } from '$lib/components/ui/drawer';
	import { ScrollArea } from '$lib/components/ui/scroll-area';

	// Props passed to the component
	export let className = '';
	export let scrollable = false;

	// Determine which component to use based on screen size
	$: Content = $isDesktop ? DialogContent : DrawerContent;
</script>

<svelte:component this={Content} class={className} {...$$restProps}>
	{#if scrollable && !$isDesktop}
		<ScrollArea>
			<slot />
		</ScrollArea>
	{:else}
		<slot />
	{/if}
</svelte:component>
