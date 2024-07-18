<script lang="ts">
	import { isDesktop } from '$lib/utils';
	import { AlertDialogContent } from '$lib/components/ui/alert-dialog';
	import { DrawerContent } from '$lib/components/ui/drawer';

	// Props passed to the component
	export let className = '';

	// Determine which component to use based on screen size
	$: Content = $isDesktop ? AlertDialogContent : DrawerContent;
</script>

<svelte:component this={Content} class={className} {...$$restProps}>
	<slot />
</svelte:component>
