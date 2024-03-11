<script lang="ts">
	import * as Tabs from '$lib/components/ui/tabs';
	import { WholeWord, Text, Scroll } from 'lucide-svelte';
	import type { FlashcardType } from '$lib/utils/ambient.d.ts';
	import { cn } from '$lib/utils';

	export let wordFlashcard: FlashcardType | undefined;

	let activeTab: string | undefined = 'conjugation';
	let conjugationData: any;

	$: if (activeTab === 'conjugation' && wordFlashcard) loadWordFlashcard();

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
		<Tabs.Trigger value="conjugation"><WholeWord class="size-5" /></Tabs.Trigger>
		<Tabs.Trigger value="sentence" disabled><Text class="size-5" /></Tabs.Trigger>
	</Tabs.List>
	<Tabs.Content value="note">{wordFlashcard?.notes}</Tabs.Content>
	<Tabs.Content value="conjugation">
		<div class={cn(!conjugationData?.error && 'grid grid-cols-3 gap-1 sm:gap-2')}>
			{#if conjugationData}
				{#each Object.keys(conjugationData) as key}
					<div class={cn('flex flex-col', key === 'Imperative' && 'col-[3/3]')}>
						<span class="text-sm">{key}</span>
						<span>{conjugationData[key]}</span>
					</div>
				{/each}
			{:else}
				<p>Loading...</p>
			{/if}
		</div>
	</Tabs.Content>
	<Tabs.Content value="sentence">Change your password here.</Tabs.Content>
</Tabs.Root>
