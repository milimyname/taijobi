<script lang="ts">
	import { isDesktop } from '$lib/utils';
	import { AlertDialogOverlay } from '$lib/components/ui/alert-dialog';
	import { DrawerOverlay } from '$lib/components/ui/drawer';
	import { Drawer as DrawerPrimitive } from 'vaul-svelte';
	import { AlertDialog as AlertDialogPrimitive } from 'bits-ui';

	type $$Props =
		| (DrawerPrimitive.OverlayProps & { className?: string })
		| (AlertDialogPrimitive.OverlayProps & { className?: string });

	// Props passed to the component
	export let className = '';

	// Determine which component to use based on screen size
	$: Overlay = $isDesktop ? AlertDialogOverlay : DrawerOverlay;
</script>

<svelte:component this={Overlay} class={className} {...$$restProps}>
	<slot />
</svelte:component>
