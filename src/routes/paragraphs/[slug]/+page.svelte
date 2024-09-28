<script lang="ts">
	import { page } from '$app/stores';
	import Button from '$lib/components/ui/button/button.svelte';
	import { pocketbase } from '$lib/utils/pocketbase';
	import { onDestroy, onMount } from 'svelte';
	import * as Tabs from '$lib/components/ui/tabs';
	import { toast } from 'svelte-sonner';
	import { storedLoading } from '$lib/utils/stores';
	import { goto } from '$app/navigation';
	import { Textarea } from '$lib/components/ui/textarea';

	export let data;

	// Get tab from url
	let tabValue = $page.url.search.split('=')[1] || 'extracted';

	let worker: Worker;
	let editable = false;

	onMount(() => {
		const setup = async () => {
			const UploadWorker = await import('$lib/workers/upload-worker?worker');
			worker = new UploadWorker.default();
		};

		setup();

		// use client side pocketbase for subscriptions
		pocketbase.authStore?.loadFromCookie(document.cookie || '');

		pocketbase
			.collection('paragraphs')
			.subscribe($page.params.slug, function (event) {
				if (event.action === 'update' && event.record?.ocr_data.fullText)
					data.paragraphs.formatted_ai_data = event.record.formatted_ai_data;
			})
			.catch((error) => {
				console.error('----error', error);
			});
	});

	async function regenerate() {
		$storedLoading = 'regenerating';

		try {
			let processingResolve: () => void;
			let processingReject: (reason?: any) => void;

			// Promise for processing
			const processingPromise = new Promise<void>((resolve, reject) => {
				processingResolve = resolve;
				processingReject = reject;
			});

			worker.postMessage({
				action: 'process',
				data: {
					prompt: data.paragraphs.ocr_data.fullText,
					recordID: data.paragraphs.id,
				},
			});

			// Handle worker messages
			worker.onmessage = (event) => {
				const { action, success, paragraphsRecordID, error } = event.data;

				if (action === 'process') {
					if (!success) processingReject(`Failed to process the image: ${error}`);

					processingResolve();
					toast('Processing complete!', {
						description: `Click to view results`,
						action: {
							label: 'View',
							onClick: () => goto(`/paragraphs/${paragraphsRecordID}?tab=details`),
						},
					});
				}
			};

			// Show processing toast
			toast.promise(processingPromise, {
				loading: 'Regenerating...',
				success: 'Regenerated successfully',
				error: (error) => `Regenerating failed: ${error}`,
				finally: () => {
					worker.terminate();
					$storedLoading = undefined;
				},
			});
		} catch (error) {
			toast.error('Failed to regenerate');
		}
	}

	async function saveEdit() {
		$storedLoading = 'savingParagraph';

		try {
			await pocketbase.collection('paragraphs').update(data.paragraphs.id, {
				ocr_data: {
					fullText: data.paragraphs.ocr_data.fullText,
				},
			});

			toast.success('Saved successfully');
		} catch (error) {
			toast.error('Failed to save');
		}

		$storedLoading = undefined;
		editable = false;
	}
</script>

<div class="mt-10 flex size-full md:mt-20">
	<Tabs.Root value={tabValue} class="w-full px-5">
		<Tabs.List>
			<Tabs.Trigger value="extracted">Extracted</Tabs.Trigger>
			<Tabs.Trigger value="details" disabled={!data.paragraphs.formatted_ai_data?.meaning}>
				Processed
			</Tabs.Trigger>
		</Tabs.List>
		<Tabs.Content value="extracted" class="w-full space-y-4 pb-10">
			<div class="flex items-center gap-2">
				<div class="flex items-center gap-2">
					<h2 class="size-full text-balance font-medium">Meaning from</h2>
					<Button variant="link" href={data.paragraphs?.url} class="p-0" target="_blank">
						this image
					</Button>
				</div>

				<Button size="sm" variant="outline" on:click={() => (editable = !editable)}>Edit</Button>

				{#if editable}
					<Button size="sm" variant="outline" on:click={saveEdit}>Save</Button>
				{/if}
			</div>

			{#if !editable}
				<p class="size-full text-balance text-xl">
					{@html data.paragraphs?.ocr_data.fullText}
				</p>
			{:else}
				<Textarea
					bind:value={data.paragraphs.ocr_data.fullText}
					rows={data.paragraphs.ocr_data.fullText.split('\n').length}
				/>
			{/if}
		</Tabs.Content>

		<Tabs.Content value="details" class="space-y-4 pb-10">
			<div class="flex items-center gap-2">
				<div class="flex items-center gap-2">
					<h2 class="size-full text-balance font-medium">Meaning from</h2>
					<Button variant="link" href={data.paragraphs?.url} class="p-0" target="_blank">
						this image
					</Button>
				</div>

				<Button
					size="sm"
					on:click={regenerate}
					disabled={$storedLoading === 'regenerating'}
					loading={$storedLoading === 'regenerating'}
				>
					Regenerate
				</Button>
			</div>

			{#if data.paragraphs.formatted_ai_data}
				<div class="space-y-4">
					<div class="space-y-2">
						<p>
							{@html data.paragraphs.formatted_ai_data.kanaWithFurigana}
						</p>
						<p>
							{@html data.paragraphs.formatted_ai_data.meaning}
						</p>
					</div>
					<div>
						{#each data.paragraphs.formatted_ai_data.detailed as text}
							<div class="grid grid-cols-3 items-center gap-2">
								<p>
									{text.kana}
								</p>
								{#if text.hiragana && text.hiragana !== text.kana}
									<p>
										{text.hiragana}
									</p>
								{/if}
								{#if text.meaning}
									<p class="col-start-3">
										{text.meaning}
									</p>
								{/if}
							</div>
						{/each}
					</div>
				</div>
			{/if}
		</Tabs.Content>
	</Tabs.Root>
</div>
