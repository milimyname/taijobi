<script lang="ts">
	import { isDesktop } from '$lib/utils';
	import { DialogOverlay } from '$lib/components/ui/dialog';
	import { DrawerOverlay } from '$lib/components/ui/drawer';

	// Props passed to the component
	export let className = '';

	// Determine which component to use based on screen size
	$: Overlay = $isDesktop ? DialogOverlay : DrawerOverlay;
</script>

<svelte:component this={Overlay} class={className} {...$$restProps}>
	<slot />
</svelte:component>
