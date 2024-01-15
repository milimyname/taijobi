<script lang="ts">
	import { Slider as SliderPrimitive } from 'bits-ui';
	import { cn } from '$lib/utils';

	type $$Props = SliderPrimitive.Props;

	let className: $$Props['class'] = undefined;
	export let value: $$Props['value'] = [30];
	export { className as class };
</script>

<SliderPrimitive.Root
	bind:value
	class={cn('relative mt-80 flex w-full touch-none select-none items-center pb-10', className)}
	{...$$restProps}
>
	<span class="relative h-14 w-full grow overflow-hidden rounded-full bg-secondary">
		<SliderPrimitive.Range class="absolute h-full bg-primary" />
	</span>
	<SliderPrimitive.Thumb
		class="border-border-input sq-[27px] active:scale-98 block h-20  w-5 cursor-pointer rounded-full border bg-background shadow transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-foreground focus-visible:ring-offset-2 disabled:pointer-events-none disabled:opacity-50"
	/>
</SliderPrimitive.Root>
