<script lang="ts">
	import { isDesktop } from '$lib/utils';
	import { DialogContent } from '$lib/components/ui/dialog';
	import { DrawerContent } from '$lib/components/ui/drawer';

	// Props passed to the component
	export let className = '';

	// Determine which component to use based on screen size
	$: Content = $isDesktop ? DialogContent : DrawerContent;
</script>

<svelte:component this={Content} class={className} {...$$restProps}>
	<slot />
</svelte:component>
