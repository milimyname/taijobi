<script lang="ts">
	import { isDesktop } from '$lib/utils';
	import { AlertDialogDescription } from '$lib/components/ui/alert-dialog';
	import { DrawerDescription } from '$lib/components/ui/drawer';
	import { Drawer as DrawerPrimitive } from 'vaul-svelte';
	import { AlertDialog as AlertDialogPrimitive } from 'bits-ui';

	// Props passed to the component
	export let className = '';

	type $$Props =
		| (DrawerPrimitive.DescriptionProps & { className?: string })
		| (AlertDialogPrimitive.Props & { className?: string });

	// Determine which component to use based on screen size
	$: Description = $isDesktop ? AlertDialogDescription : DrawerDescription;
</script>

<svelte:component this={Description} class={className} {...$$restProps}>
	<slot />
</svelte:component>
