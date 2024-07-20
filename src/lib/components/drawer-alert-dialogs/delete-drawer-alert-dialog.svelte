<script lang="ts">
	import * as DrawerAlertDialog from '$lib/components/ui/drawer-alert-dialog';
	import { deleteHistoryOpen } from '$lib/utils/stores';

	export let onClick: () => void = () => {};

	const onClose = () => setTimeout(() => ($deleteHistoryOpen = false), 100);
</script>

<DrawerAlertDialog.Root open={$deleteHistoryOpen} {onClose}>
	<slot />
	<DrawerAlertDialog.Content className="drawerNested z-[104]">
		<DrawerAlertDialog.Header>
			<DrawerAlertDialog.Title>Are you absolutely sure?</DrawerAlertDialog.Title>
			<DrawerAlertDialog.Description>
				This action cannot be undone. This will permanently delete your account and remove your data
				from our servers.
			</DrawerAlertDialog.Description>
		</DrawerAlertDialog.Header>
		<DrawerAlertDialog.Footer>
			<DrawerAlertDialog.Cancel onClick={onClose}>Cancel</DrawerAlertDialog.Cancel>
			<DrawerAlertDialog.Action {onClick} variant="destructive">Delete</DrawerAlertDialog.Action>
		</DrawerAlertDialog.Footer>
	</DrawerAlertDialog.Content>
</DrawerAlertDialog.Root>
