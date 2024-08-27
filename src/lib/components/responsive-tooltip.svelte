<script lang="ts">
	import * as Popover from '$lib/components/ui/popover';
	import * as Tooltip from '$lib/components/ui/tooltip';
	import { isDesktop } from '$lib/utils';

	export let triggerClass = '';
	export let contentClass = '';
</script>

{#if $isDesktop}
	<Tooltip.Root>
		<Tooltip.Trigger class={triggerClass}>
			<slot name="trigger">
				<!-- Default trigger content if no slot is provided -->
				<span>Hover me</span>
			</slot>
		</Tooltip.Trigger>
		<Tooltip.Content class={contentClass}>
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
		<Popover.Content class={`p-2 ${contentClass}`}>
			<slot>
				<!-- Default content if no slot is provided -->
				<p>Popover content</p>
			</slot>
		</Popover.Content>
	</Popover.Root>
{/if}
