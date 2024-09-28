<script lang="ts">
	import * as Popover from '$lib/components/ui/popover';
	import * as Tooltip from '$lib/components/ui/tooltip';
	import { cn, isDesktop } from '$lib/utils';
	import { Popover as PopoverPrimitive } from 'bits-ui';

	export let triggerClass = '';
	export let contentClass = '';
	export let align: PopoverPrimitive.ContentProps['align'] = 'center';
	export let tabindex = 0;
</script>

{#if $isDesktop}
	<Tooltip.Root>
		<Tooltip.Trigger class={triggerClass} {tabindex}>
			<slot name="trigger">
				<!-- Default trigger content if no slot is provided -->
				<span>Hover me</span>
			</slot>
		</Tooltip.Trigger>
		<Tooltip.Content class={contentClass} {align}>
			<slot>
				<!-- Default content if no slot is provided -->
				<p>Tooltip content</p>
			</slot>
		</Tooltip.Content>
	</Tooltip.Root>
{:else}
	<Popover.Root>
		<Popover.Trigger class={triggerClass}>
			<slot name="trigger">
				<!-- Default trigger content if no slot is provided -->
				<span>Click me</span>
			</slot>
		</Popover.Trigger>
		<Popover.Content class={cn('p-2', contentClass)} {align}>
			<slot>
				<!-- Default content if no slot is provided -->
				<p>Popover content</p>
			</slot>
		</Popover.Content>
	</Popover.Root>
{/if}
