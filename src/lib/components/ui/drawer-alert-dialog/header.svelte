<script lang="ts">
	import { isDesktop } from '$lib/utils';
	import { AlertDialogHeader } from '$lib/components/ui/alert-dialog';
	import { DrawerHeader } from '$lib/components/ui/drawer';
	import type { HTMLAttributes } from 'svelte/elements';

	type $$Props = HTMLAttributes<HTMLDivElement> & {
		el?: HTMLDivElement;
		className?: string;
	};

	// Props passed to the component
	export let className = '';

	// Determine which component to use based on screen size
	$: Header = $isDesktop ? AlertDialogHeader : DrawerHeader;
</script>

<svelte:component this={Header} class={className} {...$$restProps}>
	<slot />
</svelte:component>
