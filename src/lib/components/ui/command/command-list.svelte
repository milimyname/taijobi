<script lang="ts">
	import { Command as CommandPrimitive } from 'cmdk-sv';
	import { cn } from '$lib/utils';

	type $$Props = CommandPrimitive.ListProps;
	let className: string | undefined | null = undefined;
	export { className as class };
</script>

<CommandPrimitive.List
	class={cn('overflow-x-hidden md:max-h-[300px] md:overflow-y-auto', className)}
	{...$$restProps}
>
	<slot />
</CommandPrimitive.List>
