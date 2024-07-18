<script lang="ts">
	import { goto } from '$app/navigation';
	import * as DrawerAlertDialog from '$lib/components/ui/drawer-alert-dialog';
	import { pocketbase } from '$lib/utils/pocketbase';
	import { deleteHistoryOpen, openHistory } from '$lib/utils/stores';
	import { getContext } from 'svelte';
	import { toast } from 'svelte-sonner';

	const searchedFlashcardsIds = getContext<string[]>('searchedFlashcardsIds');
	const searchesIds = getContext<string[]>('searchesIds');

	async function deleteHistory() {
		try {
			await Promise.all(
				searchedFlashcardsIds?.map(async (id: string) => {
					await pocketbase.collection('flashcard').update(id, {
						searches: [],
					});
				}),
			);
		} catch (error) {
			console.error('Error deleting search history:', error);
			// toast.error('Error deleting search history. Please try again later.');
		}

		try {
			await Promise.all(
				searchesIds?.map(async (id: string) => {
					await pocketbase.collection('searches').delete(id);
				}),
			);
		} catch (error) {
			console.error('Error deleting search history:', error);
			toast.error('Error deleting search history. Please try again later.');
			return;
		}

		onClose();

		$openHistory = false;

		toast.success('Search history deleted successfully. Redirecting to the home page...');

		goto('/');
	}

	function onClose() {
		setTimeout(() => {
			$deleteHistoryOpen = false;
		}, 100);
	}
</script>

<DrawerAlertDialog.Root open={$deleteHistoryOpen} {onClose}>
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
			<DrawerAlertDialog.Action onClick={deleteHistory} variant="destructive">
				Delete
			</DrawerAlertDialog.Action>
		</DrawerAlertDialog.Footer>
	</DrawerAlertDialog.Content>
</DrawerAlertDialog.Root>
