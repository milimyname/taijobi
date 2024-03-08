<script lang="ts">
	import * as Tabs from '$lib/components/ui/tabs';
	import { WholeWord, Text, Scroll } from 'lucide-svelte';
	import type { FlashcardType } from '$lib/utils/ambient.d.ts';

	export let wordFlashcard: FlashcardType;

	let activeTab: string | undefined = 'verb-conjugation';
	let conjugationData: any;

	$: if (activeTab === 'verb-conjugation' && wordFlashcard) loadWordFlashcard();

	async function loadWordFlashcard() {
		try {
			const res = await fetch(`/api/conjugation`, {
				method: 'POST',
				headers: {
					'Content-Type': 'application/json'
				},
				body: JSON.stringify({
					word: wordFlashcard?.name
				})
			});

			if (!res.ok) return new Error('Failed to fetch word flashcard');

			conjugationData = await res.json();
		} catch (e) {
			console.error(e);
		}
	}
</script>

<Tabs.Root value={activeTab} onValueChange={(v) => (activeTab = v)}>
	<Tabs.List class="mx-auto flex w-fit">
		<Tabs.Trigger value="note" disabled={!wordFlashcard?.notes}>
			<Scroll class="size-5" />
		</Tabs.Trigger>
		<Tabs.Trigger value="verb-conjugation"><WholeWord class="size-5" /></Tabs.Trigger>
		<Tabs.Trigger value="sentence" disabled><Text class="size-5" /></Tabs.Trigger>
	</Tabs.List>
	<Tabs.Content value="note">{wordFlashcard?.notes}</Tabs.Content>
	<Tabs.Content value="verb-conjugation" class="grid grid-cols-2">
		{#if conjugationData}
			{#if conjugationData.conjugated}
				{#each Object.keys(conjugationData.conjugated) as key}
					<div class="flex flex-col">
						<span>{key}</span>
						<span>{conjugationData.conjugated[key]}</span>
					</div>
				{/each}
			{:else}
				<p>No conjugation data available</p>
			{/if}
		{:else}
			<p>Loading...</p>
		{/if}
	</Tabs.Content>
	<Tabs.Content value="sentence">Change your password here.</Tabs.Content>
</Tabs.Root>
