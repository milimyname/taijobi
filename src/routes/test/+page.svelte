<script lang="ts">
	import Button from '$lib/components/ui/button/button.svelte';
	import * as DrawerDialog from '$lib/components/ui/drawerDialog';
</script>

<DrawerDialog.Root>
	<DrawerDialog.Trigger let:builder>
		<Button
			variant="none"
			builders={[builder]}
			class="feedback-btn absolute left-1/2 top-12 z-20 -translate-x-1/2 -translate-y-1/2 border-none px-4 py-2"
		>
			a
		</Button>
		<button
			class="search-btn absolute left-1/2 top-12 z-20 ml-10 h-10 -translate-x-1/2 -translate-y-1/2 rounded-md border-none px-4 py-2"
		>
			b
		</button>
	</DrawerDialog.Trigger>

	<DrawerDialog.Content>
		<p>Drawer Dialog Content</p>
	</DrawerDialog.Content>
</DrawerDialog.Root>
