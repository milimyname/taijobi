<script lang="ts">
	import { isDesktop } from '$lib/utils';
	import { DialogFooter } from '$lib/components/ui/dialog';
	import { DrawerFooter } from '$lib/components/ui/drawer';

	// Props passed to the component
	export let className = '';

	// Determine which component to use based on screen size
	$: Footer = $isDesktop ? DialogFooter : DrawerFooter;
</script>

<svelte:component this={Footer} class={className} {...$$restProps}>
	<slot />
</svelte:component>
