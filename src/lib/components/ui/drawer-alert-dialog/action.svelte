<script lang="ts">
	import { isDesktop } from '$lib/utils';
	import { AlertDialogAction } from '$lib/components/ui/alert-dialog';
	import { Button, type Events, type Props } from '$lib/components/ui/button';
	import { AlertDialog as AlertDialogPrimitive } from 'bits-ui';

	type CommonProps = {
		className?: string;
		onClick?: () => void;
	};

	type $$Props = (AlertDialogPrimitive.ActionProps & CommonProps) | (Props & CommonProps);
	type $$Events = AlertDialogPrimitive.ActionEvents | Events;

	// Props passed to the component
	export let className = '';
	export let onClick: () => void;

	// Determine which component to use based on screen size
	$: Content = $isDesktop ? AlertDialogAction : Button;
</script>

<svelte:component this={Content} {...$$restProps} on:click={onClick} class={className}>
	<slot />
</svelte:component>
