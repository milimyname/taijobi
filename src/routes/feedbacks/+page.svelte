<script lang="ts">
	import { goto } from '$app/navigation';
	import { clickedReport } from '$lib/utils/stores';
	import { ArrowLeft } from 'lucide-svelte';
	import { superForm } from 'sveltekit-superforms/client';
	import { pocketbase } from '$lib/utils/pocketbase';
	import * as Drawer from '$lib/components/ui/drawer';
	import * as Dialog from '$lib/components/ui/dialog';
	import { isDesktop } from '$lib/utils';
	import Form from './form.svelte';
	import { feedbackSchema } from '$lib/utils/zodSchema';
	import { Button } from '$lib/components/ui/button';

	export let data;

	const superFrm = superForm(data.form, {
		validators: feedbackSchema,
		taintedMessage: null,
		applyAction: true,
		resetForm: true,
		onSubmit: () => {
			$clickedReport = false;
		},
		onUpdated: ({ form }) => {
			// Keep the form open if there is an error
			if (form.errors.name || form.errors.description) $clickedReport = true;
		}
	});

	function onCloseDrawer() {
		superFrm.reset();
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

{#if $isDesktop}
	<Dialog.Root bind:open={$clickedReport}>
		<Dialog.Overlay class="fixed inset-0 bg-black bg-opacity-30" />
		<Dialog.Content class="z-[1000] sm:max-w-[425px]">
			<Dialog.Header>
				<Dialog.Title>Feedback</Dialog.Title>
				<Dialog.Description>
					<p class="text-sm">
						You can see them here
						<a href="/feedbacks" on:click={() => ($clickedReport = false)} class="underline">
							My Feedbacks
						</a>
					</p>
				</Dialog.Description>
			</Dialog.Header>
			<Form form={superFrm} />
		</Dialog.Content>
	</Dialog.Root>
{:else}
	<Drawer.Root bind:open={$clickedReport} onClose={onCloseDrawer}>
		<Drawer.Portal>
			<Drawer.Content class="z-[100]">
				<Drawer.Header class="text-left">
					<Drawer.Title>Feedback</Drawer.Title>
					<Drawer.Description>
						<p class="text-sm">
							You can see them here
							<a href="/feedbacks" on:click={() => ($clickedReport = false)} class="underline">
								My Feedbacks
							</a>
						</p>
					</Drawer.Description>
				</Drawer.Header>
				<Form form={superFrm} />
				<Drawer.Footer>
					<Drawer.Close asChild let:builder>
						<Button builders={[builder]} variant="outline">Cancel</Button>
					</Drawer.Close>
				</Drawer.Footer>
			</Drawer.Content>
		</Drawer.Portal>
	</Drawer.Root>
{/if}
