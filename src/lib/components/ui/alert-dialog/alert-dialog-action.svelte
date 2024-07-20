<script lang="ts">
	import { AlertDialog as AlertDialogPrimitive } from 'bits-ui';
	import { buttonVariants } from '$lib/components/ui/button/index.js';
	import { cn } from '$lib/utils.js';
	import { type VariantProps, tv } from 'tailwind-variants';

	type $$Props = AlertDialogPrimitive.ActionProps & {
		variant?: VariantProps<typeof buttonVariants>['variant'];
		size?: VariantProps<typeof buttonVariants>['size'];
	};
	type $$Events = AlertDialogPrimitive.ActionEvents;

	let className: $$Props['class'] = undefined;
	export let variant: $$Props['variant'] = 'default';
	export let size: $$Props['size'] = 'default';
	export { className as class };
</script>

<AlertDialogPrimitive.Action
	class={cn(buttonVariants({ variant, size, className }))}
	{...$$restProps}
	on:click
	on:keydown
	let:builder
>
	<slot {builder} />
</AlertDialogPrimitive.Action>
