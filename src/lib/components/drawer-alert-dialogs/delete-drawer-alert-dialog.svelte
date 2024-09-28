<script lang="ts">
	import * as DrawerAlertDialog from '$lib/components/ui/drawer-alert-dialog';
	import { deleteDrawerDialogOpen } from '$lib/utils/stores';

	export let onClick: () => void = () => {};
	export let description =
		'This action cannot be undone. This will permanently delete your account and remove your data from our servers.';

	const onClose = () => setTimeout(() => ($deleteDrawerDialogOpen = false), 100);
</script>

<DrawerAlertDialog.Root open={$deleteDrawerDialogOpen} {onClose} dismissable={false}>
	<slot />
	<DrawerAlertDialog.Content className="drawerNested z-[104]">
		<DrawerAlertDialog.Header>
			<DrawerAlertDialog.Title>Are you absolutely sure?</DrawerAlertDialog.Title>
			<DrawerAlertDialog.Description>{description}</DrawerAlertDialog.Description>
		</DrawerAlertDialog.Header>
		<DrawerAlertDialog.Footer class="md:flex md:flex-row-reverse md:justify-start md:gap-2">
			<DrawerAlertDialog.Cancel asChild>
				<DrawerAlertDialog.Action {onClick} class="w-full" variant="destructive">
					Delete
				</DrawerAlertDialog.Action>
			</DrawerAlertDialog.Cancel>

			<DrawerAlertDialog.Cancel onClick={onClose}>Cancel</DrawerAlertDialog.Cancel>
		</DrawerAlertDialog.Footer>
	</DrawerAlertDialog.Content>
</DrawerAlertDialog.Root>
