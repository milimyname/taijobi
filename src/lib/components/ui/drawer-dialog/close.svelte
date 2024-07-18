<script lang="ts">
	import { isDesktop } from '$lib/utils';
	import { DialogClose } from '$lib/components/ui/dialog';
	import { DrawerClose } from '$lib/components/ui/drawer';

	// Determine which component to use based on screen size
	$: Content = $isDesktop ? DialogClose : DrawerClose;
</script>

<svelte:component this={Content} {...$$restProps} let:builder>
	<slot {builder} />
</svelte:component>
