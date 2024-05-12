<script lang="ts">
	import { isDesktop } from '$lib/utils';
	import { DialogTrigger } from '$lib/components/ui/dialog';
	import { DrawerTrigger } from '$lib/components/ui/drawer';

	// Props passed to the component
	export let className = '';

	// Determine which component to use based on screen size
	$: Trigger = $isDesktop ? DialogTrigger : DrawerTrigger;
</script>

<svelte:component this={Trigger} class={className} let:builder {...$$restProps}>
	<slot {builder} />
</svelte:component>
