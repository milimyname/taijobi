<script lang="ts">
	import { goto } from '$app/navigation';
	import { clickedReport } from '$lib/utils/stores';
	import { ArrowLeft } from 'lucide-svelte';
	import { superForm } from 'sveltekit-superforms';
	import { pocketbase } from '$lib/utils/pocketbase';
	import Form from './form.svelte';
	import { feedbackSchema } from '$lib/utils/zodSchema';
	import { Button } from '$lib/components/ui/button';
	import { zodClient } from 'sveltekit-superforms/adapters';
	import * as DrawerDialog from '$lib/components/ui/drawerDialog';

	export let data;

	const superFrm = superForm(data.form, {
		validators: zodClient(feedbackSchema),
		onUpdated: ({ form }) => {
			// Keep the form open if there is an error
			if (form.errors.name || form.errors.description) $clickedReport = true;
			else $clickedReport = false;
		}
	});

	function onCloseDrawer() {
		setTimeout(() => {
			$clickedReport = false;
			superFrm.reset();
		}, 100);
	}
</script>

<main
	class="flex h-[100dvh] select-none flex-col items-center overflow-hidden bg-white p-2 transition-all sm:px-3 sm:py-5"
>
	<nav class="flex w-full justify-between px-2 py-3 xm:p-5">
		<button on:click|preventDefault={() => goto('/')} class="flex items-center gap-2">
			<ArrowLeft
				class="size-4 transition-transform group-hover:-translate-x-2 group-active:-translate-x-2"
			/>
			<span>Back</span>
		</button>
	</nav>
	<section class="flex w-full max-w-xl flex-col gap-2 text-white">
		{#each data.feedbacks as feedback}
			<button
				class="flex w-full flex-col gap-5 rounded-lg bg-black p-4"
				on:click={() => {
					$clickedReport = true;

					superFrm.form.update((form) => {
						return {
							...form,
							name: feedback.name,
							description: feedback.description,
							device: feedback.device,
							image: pocketbase.files.getUrl(feedback, feedback.image),
							id: feedback.id
						};
					});
				}}
			>
				<div class="flex w-full justify-between">
					<h4 class="text-xl font-medium">{feedback.name}</h4>
					<p class="text-sm">{feedback.device}</p>
				</div>
				<p class="line-clamp-3 text-left text-sm">{feedback.description}</p>
			</button>
		{/each}
	</section>
</main>

<DrawerDialog.Root open={$clickedReport} onClose={onCloseDrawer}>
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
		<Form form={superFrm}>
			<div slot="delete">
				<DrawerDialog.Close asChild let:builder>
					<Button builders={[builder]} class="w-full" variant="destructive">Delete</Button>
				</DrawerDialog.Close>
			</div>
			<div slot="update">
				<DrawerDialog.Close asChild let:builder>
					<Button builders={[builder]} class="w-full">Update</Button>
				</DrawerDialog.Close>
			</div>
		</Form>
		<DrawerDialog.Footer className="md:hidden">
			<DrawerDialog.Close asChild let:builder>
				<Button builders={[builder]} variant="outline">Cancel</Button>
			</DrawerDialog.Close>
		</DrawerDialog.Footer>
	</DrawerDialog.Content>
</DrawerDialog.Root>
