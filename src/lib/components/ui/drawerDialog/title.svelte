<script lang="ts">
	import { isDesktop } from '$lib/utils';
	import { DialogTitle } from '$lib/components/ui/dialog';
	import { DrawerTitle } from '$lib/components/ui/drawer';

	// Props passed to the component
	export let className = '';

	// Determine which component to use based on screen size
	$: Title = $isDesktop ? DialogTitle : DrawerTitle;
</script>

<svelte:component this={Title} class={className} {...$$restProps}>
	<slot />
</svelte:component>
