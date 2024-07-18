<script lang="ts">
	import { isDesktop } from '$lib/utils';
	import { AlertDialogFooter } from '$lib/components/ui/alert-dialog';
	import { DrawerFooter } from '$lib/components/ui/drawer';
	import type { HTMLAttributes } from 'svelte/elements';

	type $$Props = HTMLAttributes<HTMLDivElement> & {
		el?: HTMLDivElement;
		className?: string;
	};

	// Props passed to the component
	export let className = '';

	// Determine which component to use based on screen size
	$: Footer = $isDesktop ? AlertDialogFooter : DrawerFooter;
</script>

<svelte:component this={Footer} class={className} {...$$restProps}>
	<slot />
</svelte:component>
