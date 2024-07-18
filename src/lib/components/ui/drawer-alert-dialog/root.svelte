<script lang="ts">
	import { isDesktop } from '$lib/utils';
	import { AlertDialog } from '$lib/components/ui/alert-dialog';
	import { Drawer } from '$lib/components/ui/drawer';

	export let open = false;

	// Determine which component to use based on screen size
	$: Root = $isDesktop ? AlertDialog : Drawer;
</script>

<svelte:component this={Root} bind:open {...$$restProps}>
	<slot />
</svelte:component>
