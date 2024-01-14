<script lang="ts">
	import { Slider as SliderPrimitive } from 'bits-ui';
	import { cn } from '$lib/utils';

	type $$Props = SliderPrimitive.Props;

	let className: $$Props['class'] = undefined;
	export let value: $$Props['value'] = [0];
	export { className as class };
</script>

<SliderPrimitive.Root
	bind:value
	class={cn('relative flex w-full touch-none select-none items-center', className)}
	{...$$restProps}
>
	<span
		class="relative h-14 touch-none select-none w-full grow overflow-hidden rounded-full bg-secondary"
	>
		<SliderPrimitive.Range class="absolute touch-none select-none h-full bg-primary" />
	</span>
	<SliderPrimitive.Thumb
		class="block h-14 w-3 rounded-full border-2 touch-none select-none border-primary bg-background ring-offset-background transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:pointer-events-none disabled:opacity-50"
	/>
</SliderPrimitive.Root>
