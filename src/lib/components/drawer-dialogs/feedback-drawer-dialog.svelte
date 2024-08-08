<script lang="ts">
	import * as DrawerDialog from '$lib/components/ui/drawer-dialog';
	import { clickedFeedback, clickedReport, deleteDrawerDialogOpen } from '$lib/utils/stores';
	import { Button } from '$lib/components/ui/button';
	import { type FeedbackSchema } from '$lib/utils/zodSchema';
	import { type SuperForm, type Infer } from 'sveltekit-superforms';
	import FeedbackReadForm from '$lib/components/ui/form/feedback-read-form.svelte';
	import { getContext } from 'svelte';
	import DeleteDrawerAlertDialog from '$lib/components/drawer-alert-dialogs/delete-drawer-alert-dialog.svelte';
	import { cn } from '$lib/utils';
	import DeleteTrashButton from '$lib/components/delete-trash-button.svelte';

	let form: SuperForm<Infer<FeedbackSchema>> = getContext('feedbackForm');

	const { reset, isTainted, tainted, delayed } = form;

	function onCloseDrawer() {
		if ($deleteDrawerDialogOpen) return;

		setTimeout(() => {
			$clickedReport = false;
			$clickedFeedback = false;
			reset();
		}, 100);
	}

	function deleteFeedback() {
		form.submit();
		setTimeout(() => ($deleteDrawerDialogOpen = false), 150);
	}

	$: disabled = !isTainted($tainted);
</script>

<DeleteDrawerAlertDialog onClick={deleteFeedback} />

<DrawerDialog.Root open={$clickedReport} onClose={onCloseDrawer} onOutsideClick={onCloseDrawer}>
	<DrawerDialog.Content
		className={cn(
			'max-md:fixed max-md:bottom-0 max-md:left-0 max-md:right-0 max-md:flex max-md:h-full max-md:max-h-[96%] max-md:flex-col',
			$deleteDrawerDialogOpen && 'z-60',
		)}
	>
		<DrawerDialog.Header class="text-left">
			<DrawerDialog.Title className="flex justify-between items-center">
				<span>Leave a feedback or report a bug!</span>
				<DeleteTrashButton loading={$delayed} />
			</DrawerDialog.Title>
		</DrawerDialog.Header>
		<FeedbackReadForm {disabled}>
			<DrawerDialog.Close asChild let:builder>
				<Button builders={[builder]} class="w-full" loading={$delayed} {disabled}>Update</Button>
			</DrawerDialog.Close>
		</FeedbackReadForm>
		<DrawerDialog.Footer>
			<DrawerDialog.Close asChild let:builder>
				<Button builders={[builder]} variant="outline">Cancel</Button>
			</DrawerDialog.Close>
		</DrawerDialog.Footer>
	</DrawerDialog.Content>
</DrawerDialog.Root>
