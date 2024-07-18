<script lang="ts">
	import { isDesktop } from '$lib/utils';
	import { DialogDescription } from '$lib/components/ui/dialog';
	import { DrawerDescription } from '$lib/components/ui/drawer';

	// Props passed to the component
	export let className = '';

	// Determine which component to use based on screen size
	$: Description = $isDesktop ? DialogDescription : DrawerDescription;
</script>

<svelte:component this={Description} class={className} {...$$restProps}>
	<slot />
</svelte:component>
