<script lang="ts">
	import { deleteHistoryOpen } from '$lib/utils/stores';
	import { Trash2 } from 'lucide-svelte';
	import { Button } from '$lib/components/ui/button';
	import { cn } from '$lib/utils';

	export let loading = false;
	export let className = '';
	export let onClick: (e: MouseEvent) => void = () => {};
</script>

<Button
	size="icon"
	{loading}
	variant="none"
	class={cn('size-fit', className)}
	on:click={(e) => {
		onClick(e);
		$deleteHistoryOpen = true;
	}}
>
	<Trash2 class="size-4" />
</Button>
