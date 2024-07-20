<script lang="ts">
	import * as DrawerDialog from '$lib/components/ui/drawer-dialog';
	import { goto } from '$app/navigation';
	import { clickedReport, deleteHistoryOpen } from '$lib/utils/stores';
	import { Button } from '$lib/components/ui/button';
	import { type FeedbackSchema } from '$lib/utils/zodSchema';
	import { type SuperForm, type Infer } from 'sveltekit-superforms';
	import FeedbackReadForm from '$lib/components/ui/form/feedback-read-form.svelte';
	import { getContext } from 'svelte';
	import DeleteDrawerAlertDialog from '$lib/components/drawer-alert-dialogs/delete-drawer-alert-dialog.svelte';
	import { Trash2 } from 'lucide-svelte';
	import { cn } from '$lib/utils';

	let form: SuperForm<Infer<FeedbackSchema>> = getContext('feedbackForm');

	const { reset, isTainted, tainted, delayed } = form;

	function onCloseDrawer() {
		if ($deleteHistoryOpen) return;

		setTimeout(() => {
			$clickedReport = false;
			reset();
		}, 100);
	}

	function deleteFeedback() {
		form.submit();
		setTimeout(() => ($deleteHistoryOpen = false), 150);
	}

	$: disabled = !isTainted($tainted);
</script>

<DeleteDrawerAlertDialog onClick={deleteFeedback} />

<DrawerDialog.Root open={$clickedReport} onClose={onCloseDrawer} onOutsideClick={onCloseDrawer}>
	<DrawerDialog.Content className={cn($deleteHistoryOpen && 'z-60')}>
		<DrawerDialog.Header class="text-left">
			<DrawerDialog.Title className="flex justify-between items-center">
				<span>Leave a feedback or report a bug!</span>
				<Button
					size="icon"
					variant="none"
					class="size-fit"
					on:click={() => ($deleteHistoryOpen = true)}
				>
					<Trash2 class="size-4" />
				</Button>
			</DrawerDialog.Title>
			<DrawerDialog.Description>
				<p class="text-sm">
					Feedback
					<DrawerDialog.Close>
						<button
							on:click={() => {
								$clickedReport = false;
								goto('/feedbacks');
							}}
							class="underline"
						>
							My Feedbacks
						</button>
					</DrawerDialog.Close>
				</p>
			</DrawerDialog.Description>
		</DrawerDialog.Header>
		<FeedbackReadForm {disabled}>
			<div slot="update">
				<DrawerDialog.Close asChild let:builder>
					<Button builders={[builder]} class="w-full" loading={$delayed} {disabled}>Update</Button>
				</DrawerDialog.Close>
			</div>
		</FeedbackReadForm>
		<DrawerDialog.Footer className="md:hidden">
			<DrawerDialog.Close asChild let:builder>
				<Button builders={[builder]} variant="outline">Cancel</Button>
			</DrawerDialog.Close>
		</DrawerDialog.Footer>
	</DrawerDialog.Content>
</DrawerDialog.Root>
