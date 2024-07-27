<script lang="ts">
	import { cn, isDesktop } from '$lib/utils';
	import { AlertDialogCancel } from '$lib/components/ui/alert-dialog';
	import { DrawerClose } from '$lib/components/ui/drawer';
	import { AlertDialog as AlertDialogPrimitive } from 'bits-ui';
	import { buttonVariants } from '$lib/components/ui/button';

	type $$Props = AlertDialogPrimitive.ActionProps | typeof DrawerClose.ActionProps;
	type $$Events = AlertDialogPrimitive.ActionEvents | typeof DrawerClose.ActionEvents;

	export let className = 'border bg-gray-100 text-gray-800';
	export let onClick: () => void;

	// Determine which component to use based on screen size
	$: Content = $isDesktop ? AlertDialogCancel : DrawerClose;
</script>

<svelte:component
	this={Content}
	{...$$restProps}
	let:builder
	on:click={onClick}
	class={cn(buttonVariants({ variant: 'outline' }), className)}
>
	<slot {builder} />
</svelte:component>
