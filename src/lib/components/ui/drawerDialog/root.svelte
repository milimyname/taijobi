<script lang="ts">
	import { isDesktop } from '$lib/utils';
	import { Dialog } from '$lib/components/ui/dialog';
	import { Drawer } from '$lib/components/ui/drawer';

	export let open = false;
	export let onOutsideClick = (e: MouseEvent | TouchEvent | PointerEvent) => {};

	// Determine which component to use based on screen size
	$: Root = $isDesktop ? Dialog : Drawer;
</script>

<svelte:component this={Root} bind:open {onOutsideClick} {...$$restProps}>
	<slot />
</svelte:component>
