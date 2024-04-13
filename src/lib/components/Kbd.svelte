<script>
	import { getHotkeyPrefix } from '$lib/utils';
</script>

<p class="fixed bottom-5 left-5 hidden text-sm text-muted-foreground lg:block">
	Press
	<kbd
		class="pointer-events-none inline-flex h-5 select-none items-center gap-1 rounded border bg-muted px-1.5 font-mono text-[10px] font-medium text-muted-foreground opacity-100"
	>
		<span class="text-xs">{getHotkeyPrefix()}</span>K
	</kbd>
</p>
