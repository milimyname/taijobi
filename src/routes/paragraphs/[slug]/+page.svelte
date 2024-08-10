<script lang="ts">
	import { page } from '$app/stores';
	import Button from '$lib/components/ui/button/button.svelte';
	import { pocketbase } from '$lib/utils/pocketbase';
	import { onDestroy, onMount } from 'svelte';
	import * as Tabs from '$lib/components/ui/tabs';

	export let data;

	// Get tab from url
	let tabValue = $page.url.search.split('=')[1] || 'extracted';

	onMount(() => {
		if (data.paragraphs.formatted_ai_data) return;
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

	onDestroy(() => {
		// destroy client when component is destroyed
		pocketbase?.authStore?.clear();
	});
</script>

<div class="mt-20 flex size-full">
	<Tabs.Root value={tabValue} class="px-5">
		<Tabs.List>
			<Tabs.Trigger value="extracted">Extracted</Tabs.Trigger>
			<Tabs.Trigger value="formatted" disabled={!data.paragraphs.formatted_ai_data?.kana}>
				Formatted
			</Tabs.Trigger>
			<Tabs.Trigger value="details" disabled={!data.paragraphs.formatted_ai_data?.meaning}>
				Details
			</Tabs.Trigger>
		</Tabs.List>
		<Tabs.Content value="extracted">
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
		<Tabs.Content value="formatted">
			<h2 class="size-full text-balance font-medium">
				Formatted text from
				<Button variant="link" href={data.paragraphs?.url} class="px-0" target="_blank">
					this image
				</Button>
			</h2>
			<p class="size-full text-balance text-xl">
				{@html data.paragraphs.formatted_ai_data?.kana}
			</p>
		</Tabs.Content>
		<Tabs.Content value="details">
			<h2 class="size-full text-balance font-medium">
				Meaning from
				<Button variant="link" href={data.paragraphs?.url} class="px-0" target="_blank">
					this image
				</Button>
			</h2>

			{#if data.paragraphs.formatted_ai_data}
				<div class="space-y-4">
					<div class="space-y-2">
						<p>
							{@html data.paragraphs.formatted_ai_data.kana}
						</p>
						<p>
							{@html data.paragraphs.formatted_ai_data.meaning}
						</p>
					</div>
					<div>
						{#each data.paragraphs.formatted_ai_data.detailed as text}
							<div class="flex grid grid-cols-3 items-center gap-2">
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
