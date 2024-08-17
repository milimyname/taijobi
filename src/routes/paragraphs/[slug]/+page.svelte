<script lang="ts">
	import { page } from '$app/stores';
	import Button from '$lib/components/ui/button/button.svelte';
	import { pocketbase } from '$lib/utils/pocketbase';
	import { onDestroy, onMount } from 'svelte';
	import * as Tabs from '$lib/components/ui/tabs';
	import { toast } from 'svelte-sonner';
	import { loading } from '$lib/utils/stores';
	import { goto } from '$app/navigation';

	export let data;

	// Get tab from url
	let tabValue = $page.url.search.split('=')[1] || 'extracted';

	let worker: Worker;

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
		$loading = true;

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
					$loading = false;
				},
			});
		} catch (error) {
			toast.error('Failed to regenerate');
		}
	}

	onDestroy(() => {
		// destroy client when component is destroyed
		pocketbase?.authStore?.clear();
	});
</script>

<div class="mt-10 flex size-full md:mt-20">
	<Tabs.Root value={tabValue} class="px-5">
		<Tabs.List>
			<Tabs.Trigger value="extracted">Extracted</Tabs.Trigger>
			<Tabs.Trigger value="details" disabled={!data.paragraphs.formatted_ai_data?.meaning}>
				Processed
			</Tabs.Trigger>
		</Tabs.List>
		<Tabs.Content value="extracted" class="pb-5">
			<h2 class="size-full text-balance font-medium">
				One to One extracted text from
				<Button variant="link" href={data.paragraphs?.url} class="px-0" target="_blank">
					this image
				</Button>
			</h2>
			<p class="size-full text-balance text-xl">
				{@html data.paragraphs?.ocr_data.fullText}
			</p>
		</Tabs.Content>

		<Tabs.Content value="details" class="space-y-4">
			<h2 class="size-full text-balance font-medium">
				Meaning from
				<Button variant="link" href={data.paragraphs?.url} class="px-0" target="_blank">
					this image
				</Button>

				<Button class="ml-2" size="sm" on:click={regenerate} disabled={$loading} loading={$loading}>
					Regenerate
				</Button>
			</h2>

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
