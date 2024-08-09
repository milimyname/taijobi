<script lang="ts">
	import { Command as CommandPrimitive } from 'cmdk-sv';
	import { LoaderCircle, Search } from 'lucide-svelte';
	import { cn } from '$lib/utils';
	import { loading } from '$lib/utils/stores';

	type $$Props = CommandPrimitive.InputProps;

	let className: string | undefined | null = undefined;
	export { className as class };
	export let value: string = '';
</script>

<div class="flex items-center border-b px-2" data-cmdk-input-wrapper="">
	{#if $loading}
		<LoaderCircle class="mr-2 size-4  shrink-0 animate-spin" />
	{:else}
		<Search class="mr-2 size-5 shrink-0 opacity-50" />
	{/if}

	<CommandPrimitive.Input
		class={cn(
			'flex h-11 w-full rounded-md bg-transparent py-3 text-sm outline-none placeholder:text-muted-foreground disabled:cursor-not-allowed disabled:opacity-50',
			className,
		)}
		{...$$restProps}
		bind:value
	/>
</div>
