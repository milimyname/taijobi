<script lang="ts">
	import * as Tabs from '$lib/components/ui/tabs';
	import { WholeWord, Text, Scroll } from 'lucide-svelte';
	import type { FlashcardType } from '$lib/utils/ambient.d.ts';
	import { cn } from '$lib/utils';
	import * as Select from '$lib/components/ui/select';
	import { page } from '$app/stores';

	export let wordFlashcard: FlashcardType | undefined;

	let activeTab: string | undefined = 'conjugation';
	let conjugationData: any;
	let exampleSentences: { sentence: string; meaning: string }[] = [];
	let currentItem: string | unknown;

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

	async function generateexampleSentences() {
		try {
			const res = await fetch(`/api/chat`, {
				method: 'POST',
				headers: {
					'Content-Type': 'application/json'
				},
				body: JSON.stringify({
					input: currentItem
				})
			});

			if (!res.ok) throw new Error('Failed to fetch sentence examples');

			// Stream processing
			const data = await res.json();

			exampleSentences = [...exampleSentences, ...data.exampleSentences];
		} catch (e) {
			console.error(e);
		}
	}

	$: if (activeTab === 'conjugation' && wordFlashcard) loadWordFlashcard();
	$: if (activeTab === 'sentence' && wordFlashcard) exampleSentences = [];
	const test = [
		{
			sentence: '家に着く前に電話します。',
			meaning: 'I will call before arriving home.'
		},
		{
			sentence: '駅に着いてから、友達と待ち合わせました。',
			meaning: 'I arrived at the station and met with my friend.'
		},
		{
			sentence: '今朝、学校に着いたら授業が始まっていた。',
			meaning: 'When I arrived at school this morning, the class had already started.'
		},
		{
			sentence: '彼女はいつも遅刻するので、そろそろ着ないと。',
			meaning: 'She always runs late, so she should hurry up and arrive.'
		},
		{
			sentence: '明日のパーティーには、黒いドレスを着ます。',
			meaning: 'I will wear a black dress to the party tomorrow.'
		},
		{
			sentence: '平日はスーツを着ませんが、土日は着ます。',
			meaning: "I don't wear a suit on weekdays, but I wear one on the weekends."
		},
		{
			sentence: 'お母さんは昨日、美しい着物を着ました。',
			meaning: 'Yesterday, my mother wore a beautiful kimono.'
		},
		{
			sentence: '高校時代の友達が結婚式に来るので、洋服を着ませんでした。',
			meaning: "My high school friends are coming to the wedding, so I didn't wear Western clothes."
		},
		{
			sentence: '新しい道具を使えば、短時間で手紙を書き終えることができるだろう。',
			meaning: 'If you use the new tool, you will be able to finish writing the letter quickly.'
		},
		{
			sentence: '試験の準備はしっかりとしておかないと、着ろ、後悔するよ。',
			meaning: 'If you don’t prepare well for the exam, persevere, you will regret it.'
		}
	];
</script>

<Tabs.Root
	value={activeTab}
	onValueChange={(v) => (activeTab = v)}
	class="h-full overflow-y-scroll"
>
	<Tabs.List class="sticky top-0 mx-auto flex w-fit">
		<Tabs.Trigger value="note" disabled={!wordFlashcard?.notes}>
			<Scroll class="size-5" />
		</Tabs.Trigger>
		<Tabs.Trigger value="conjugation"><WholeWord class="size-5" /></Tabs.Trigger>
		<Tabs.Trigger value="sentence" disabled={conjugationData?.error || !$page.data.isLoggedIn}>
			<Text class="size-5" />
		</Tabs.Trigger>
	</Tabs.List>
	<Tabs.Content value="note">{wordFlashcard?.notes}</Tabs.Content>
	<Tabs.Content value="conjugation">
		<div class={cn(!conjugationData?.error && 'grid grid-cols-3 gap-1 sm:gap-2')}>
			{#if conjugationData}
				{#each Object.keys(conjugationData) as key}
					<div class={cn('flex flex-col', key === 'Imperative' && 'col-[3/3]')}>
						<span class="text-sm font-semibold">{key}</span>
						<span>{conjugationData[key]}</span>
					</div>
				{/each}
			{:else}
				<p>Loading...</p>
			{/if}
		</div>
	</Tabs.Content>
	<Tabs.Content value="sentence" class="space-y-2 pb-14">
		{#if exampleSentences}
			{#each exampleSentences as { sentence, meaning }}
				<div class="flex flex-col gap-1">
					<span>{@html sentence}</span>
					<span class="text-sm">{meaning}</span>
				</div>
			{/each}
		{:else}
			<p>Loading...</p>
		{/if}
		{#each test as { sentence, meaning }}
			<div class="flex flex-col gap-1">
				<span>{@html sentence}</span>
				<span class="text-sm">{meaning}</span>
			</div>
		{/each}
	</Tabs.Content>
</Tabs.Root>

{#if activeTab === 'sentence'}
	<Select.Root
		onSelectedChange={async (item) => {
			currentItem = item?.value;
			await generateexampleSentences();
		}}
	>
		<Select.Trigger
			class="flashcard-completion-btn absolute bottom-3 right-1/2 flex w-[180px] translate-x-1/2 gap-2 bg-white text-black"
		>
			<Select.Value />
		</Select.Trigger>
		<Select.Content class="flashcard-completion-btn">
			{#each Object.values(conjugationData) as conjugation}
				<Select.Item value={conjugation}>
					{conjugation}
				</Select.Item>
			{/each}
		</Select.Content>
	</Select.Root>
{/if}
