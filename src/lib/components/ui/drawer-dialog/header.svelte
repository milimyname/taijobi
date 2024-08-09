<script lang="ts">
	import { cn, isDesktop } from '$lib/utils';
	import { DialogHeader } from '$lib/components/ui/dialog';
	import { DrawerHeader } from '$lib/components/ui/drawer';

	// Props passed to the component
	export let className = '';

	// Determine which component to use based on screen size
	$: Header = $isDesktop ? DialogHeader : DrawerHeader;
</script>

<svelte:component this={Header} class={cn('text-left', className)} {...$$restProps}>
	<slot />
</svelte:component>
