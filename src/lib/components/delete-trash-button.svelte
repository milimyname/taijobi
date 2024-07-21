<script>
	import { deleteHistoryOpen } from '$lib/utils/stores';
	import { Trash2 } from 'lucide-svelte';
	import { Button } from '$lib/components/ui/button';
</script>

<Button size="icon" variant="none" class="size-fit" on:click={() => ($deleteHistoryOpen = true)}>
	<Trash2 class="size-4" />
</Button>
