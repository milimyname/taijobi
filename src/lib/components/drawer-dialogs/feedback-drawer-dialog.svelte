<script lang="ts">
	import * as DrawerDialog from '$lib/components/ui/drawerDialog';
	import { goto } from '$app/navigation';
	import { clickedReport } from '$lib/utils/stores';
	import { Button } from '$lib/components/ui/button';
	import { type FeedbackSchema } from '$lib/utils/zodSchema';
	import { type SuperForm, type Infer } from 'sveltekit-superforms';
	import FeedbackReadForm from '$lib/components/ui/form/feedback-read-form.svelte';
	import { getContext } from 'svelte';

	let form: SuperForm<Infer<FeedbackSchema>> = getContext('feedbackForm');

	const { reset, isTainted, tainted, delayed } = form;

	function onCloseDrawer() {
		setTimeout(() => {
			$clickedReport = false;
			reset();
		}, 100);
	}

	$: disabled = !isTainted($tainted);
</script>

<DrawerDialog.Root open={$clickedReport} onClose={onCloseDrawer} onOutsideClick={onCloseDrawer}>
	<DrawerDialog.Content>
		<DrawerDialog.Header class="text-left">
			<DrawerDialog.Title>Leave a feedback or report a bug!</DrawerDialog.Title>
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
			<div slot="delete">
				<DrawerDialog.Close asChild let:builder>
					<Button builders={[builder]} class="w-full" variant="destructive" loading={$delayed}>
						Delete
					</Button>
				</DrawerDialog.Close>
			</div>
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
