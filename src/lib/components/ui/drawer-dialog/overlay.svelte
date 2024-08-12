<script lang="ts">
	import { cn, isDesktop } from '$lib/utils';
	import { DialogOverlay } from '$lib/components/ui/dialog';
	import { DrawerOverlay } from '$lib/components/ui/drawer';

	// Props passed to the component
	export let className = '';

	// Determine which component to use based on screen size
	$: Overlay = $isDesktop ? DialogOverlay : DrawerOverlay;
</script>

<svelte:component
	this={Overlay}
	class={cn('fixed inset-0 z-50 bg-black/10', className)}
	{...$$restProps}
>
	<slot />
</svelte:component>
