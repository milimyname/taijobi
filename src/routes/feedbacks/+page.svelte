<script lang="ts">
	import { goto } from '$app/navigation';
	import { clickedReport, clickedFeedback } from '$lib/utils/stores';
	import { ArrowDown01, ArrowDown10, ArrowLeft } from 'lucide-svelte';
	import { superForm } from 'sveltekit-superforms';
	import { pocketbase } from '$lib/utils/pocketbase';
	import { feedbackSchema } from '$lib/utils/zodSchema';
	import { Button } from '$lib/components/ui/button';
	import { zodClient } from 'sveltekit-superforms/adapters';
	import type { RecordModel } from 'pocketbase';
	import Badge from '$lib/components/ui/badge/badge.svelte';
	import FeedbackDrawerDialog from '$lib/components/drawer-dialogs/feedback-drawer-dialog.svelte';
	import { setContext } from 'svelte';

	export let data;

	let sortedByDate = false;

	const superFrm = superForm(data.form, {
		validators: zodClient(feedbackSchema),
		onUpdated: ({ form }) => {
			// Keep the form open if there is an error
			if (form.errors.name || form.errors.description) $clickedReport = true;
			else $clickedReport = false;
		},
	});

	setContext('feedbackForm', superFrm);

	function onClickFeedback(feedback: RecordModel) {
		$clickedReport = true;

		superFrm.reset({
			data: {
				name: feedback.name,
				description: feedback.description,
				device: feedback.device,
				image: pocketbase.files.getUrl(feedback, feedback.image),
				id: feedback.id,
			},
		});
	}

	$: feedbacks = (() => {
		// Then, sort the filtered quizzes based on sortedByDate

		if (!data.feedbacks) return [];

		return sortedByDate
			? data.feedbacks.sort(
					(a: RecordModel, b: RecordModel) =>
						Number(new Date(b.created)) - Number(new Date(a.created)),
				)
			: data.feedbacks.sort(
					(a: RecordModel, b: RecordModel) =>
						Number(new Date(a.created)) - Number(new Date(b.created)),
				);
	})();
</script>

<FeedbackDrawerDialog />

<main class="flex h-dvh flex-col items-center bg-white transition-all">
	<nav class="flex w-full justify-between p-2 py-3 sm:px-3 sm:py-5">
		<Button size="icon" variant="none">
			<a href="/" class="go-back-btn group" data-sveltekit-preload-data>
				<ArrowLeft
					class="size-4 transition-transform  group-hover:-translate-x-2 group-active:-translate-x-2"
				/>
			</a>
		</Button>
	</nav>
	<section class="flex w-full max-w-xl flex-col gap-2 max-md:pb-4 md:space-y-2">
		<div class="sticky top-4 flex flex-wrap gap-2 bg-white max-md:p-4">
			<Button size="sm" variant="outline" on:click={() => (sortedByDate = !sortedByDate)}>
				{#if sortedByDate}
					<ArrowDown10 class="mr-2 size-5" />
				{:else}
					<ArrowDown01 class="mr-2 size-5" />
				{/if}

				<span>Sorted by date</span>
			</Button>
			<Button size="sm" on:click={() => ($clickedFeedback = true)}>Create</Button>
		</div>
		<div class="grid grid-flow-row gap-4 max-md:px-4 md:grid-cols-3">
			{#each feedbacks as feedback}
				<button
					class="flex w-full flex-col justify-between gap-2 rounded-lg border p-4 transition-all hover:shadow-md md:hover:scale-105"
					on:click={() => onClickFeedback(feedback)}
				>
					<p class="line-clamp-3 text-left text-sm">{feedback.description}</p>
					<Badge variant="outline" class="w-fit">
						{new Date(feedback.created).toLocaleDateString()}
					</Badge>
				</button>
			{/each}
		</div>
	</section>
</main>
