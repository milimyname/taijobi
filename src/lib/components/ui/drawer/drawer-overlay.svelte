<script lang="ts">
	import { Drawer as DrawerPrimitive } from 'vaul-svelte';
	import { cn } from '$lib/utils';

	type $$Props = DrawerPrimitive.OverlayProps;

	export let el: $$Props['el'] = undefined;
	let className: $$Props['class'] = undefined;
	export { className as class };
</script>

<DrawerPrimitive.Overlay
	bind:el
	class={cn('fixed inset-[-1px] z-50 rounded-lg bg-black/80', className)}
	{...$$restProps}
>
	<slot />
</DrawerPrimitive.Overlay>
