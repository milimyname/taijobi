<script lang="ts">
	import { goto } from '$app/navigation';
	import { clickedReport } from '$lib/utils/stores';
	import { ArrowLeft } from 'lucide-svelte';
	import { superForm } from 'sveltekit-superforms/client';
	import { pocketbase } from '$lib/utils/pocketbase';
	import * as Drawer from '$lib/components/ui/drawer';
	import { Button } from '$lib/components/ui/button';
	import * as Dialog from '$lib/components/ui/dialog';
	import { isDesktop } from '$lib/utils';
	import Form from './form.svelte';

	export let data;

	let showImage = false;

	const { form, errors, constraints, enhance } = superForm(data.form, {
		taintedMessage: null,
		resetForm: true,
		applyAction: true,
		onSubmit: () => {
			if ($isDesktop) $clickedReport = false;
		},
		onUpdated: () => {
			if ($errors.name || $errors.description) $clickedReport = true;
		}
	});

	function onCloseDrawer() {
		$form.name = '';
		$form.description = '';
		$form.device = '';
		$form.id = '';
		$form.image = '';
	}
</script>

{#if showImage && $form.image !== ''}
	<div class="fixed top-0 z-[1010] h-screen w-full bg-black opacity-50 transition-all" />
	<img
		src={$form.image}
		alt="Feedback Preview"
		class="absolute left-1/2 top-1/2 z-[2000] -translate-x-1/2 -translate-y-1/2"
	/>
	<button
		on:click={() => (showImage = false)}
		class="absolute left-1/2 top-[80%] z-[2010] -translate-x-1/2 -translate-y-1/2 bg-black px-4 py-2 font-bold text-white"
	>
		Close
	</button>
{/if}

<main
	class="flex h-screen overflow-y-scroll select-none flex-col items-center gap-10 overflow-hidden bg-white px-3 py-11 transition-all"
>
	<nav class="z-[99] flex w-full justify-between">
		<button on:click|preventDefault={() => goto('/')} class="flex items-center gap-2">
			<ArrowLeft class="h-5 w-5 " />
			<span>Back</span>
		</button>
	</nav>
	<section class="flex w-full flex-col gap-2 text-white">
		{#each data.feedbacks as feedback}
			<button
				class="flex w-full flex-col gap-5 rounded-lg bg-black p-4"
				on:click={() => {
					$clickedReport = true;

					$form.name = feedback.name;
					$form.description = feedback.description;
					$form.device = feedback.device;
					$form.id = feedback.id;
					$form.userId = feedback.userId;

					$form.image = pocketbase.files.getUrl(feedback, feedback.image);
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
		<Dialog.Content class="sm:max-w-[425px] z-[1000]">
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
			<Form {enhance} {errors} {constraints} {form} {showImage} />
		</Dialog.Content>
	</Dialog.Root>
{:else}
	<Drawer.Root bind:open={$clickedReport} shouldScaleBackground>
		<Drawer.Portal>
			<Drawer.Overlay class="fixed inset-0 -z-10 bg-black bg-opacity-30" />
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
				<Form {enhance} {errors} {constraints} {form} {showImage} />
				<Drawer.Footer>
					<Drawer.Close asChild let:builder>
						<Button builders={[builder]} variant="outline" on:click={onCloseDrawer}>Cancel</Button>
					</Drawer.Close>
				</Drawer.Footer>
			</Drawer.Content>
		</Drawer.Portal>
	</Drawer.Root>
{/if}

<style>
	.disable-pointer-events {
		pointer-events: none;
	}
</style>
