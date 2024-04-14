<script lang="ts">
	import * as Tabs from '$lib/components/ui/tabs';
	import { WholeWord, Text, Scroll, Volume2 } from 'lucide-svelte';
	import type { FlashcardType } from '$lib/utils/ambient.d.ts';
	import { cn } from '$lib/utils';
	import * as Select from '$lib/components/ui/select';
	import { page } from '$app/stores';

	export let wordFlashcard: FlashcardType | undefined;

	let audioSource: string = '';
	let audioElement: HTMLAudioElement;
	let activeTab: string | undefined = wordFlashcard?.notes ? 'note' : 'conjugation';
	let conjugationData: any;
	let exampleSentences: { sentence: string; meaning: string; furigana: string }[] = [];
	let selectedValue: { value: unknown; label?: string };

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

			if (!res.ok) throw new Error('Failed to fetch word flashcard');

			conjugationData = await res.json();
		} catch (e) {
			console.error(e);
		}
	}

	async function generateExampleSentences() {
		try {
			const res = await fetch('/api/openai', {
				method: 'POST',
				headers: {
					'Content-Type': 'application/json'
				},
				body: JSON.stringify({
					input: selectedValue?.value,
					type: 'text'
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

	async function convertTextToSpeech(input: string) {
		try {
			const res = await fetch('/api/openai', {
				method: 'POST',
				headers: {
					'Content-Type': 'application/json'
				},
				body: JSON.stringify({ input, type: 'audio' })
			});

			if (!res.ok) throw new Error('Failed to fetch audio');

			const data = await res.json();

			const audioData = data.audioData;

			audioSource = `data:audio/mp3;base64,${audioData}`;
		} catch (e) {
			console.error(e);
		}
	}

	$: if (activeTab === 'conjugation' || wordFlashcard) loadWordFlashcard();
	$: if (activeTab === 'sentence' && wordFlashcard) exampleSentences = [];

	$: if (wordFlashcard)
		selectedValue = {
			value: '',
			label: ''
		};
</script>

{#if audioSource}
	<audio src={audioSource} bind:this={audioElement} />
{/if}

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
		<Tabs.Trigger value="sentence" disabled={!$page.data.isLoggedIn}>
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
			{#each exampleSentences as { furigana, sentence, meaning }}
				<div class="flex gap-2">
					<div class="flex flex-col gap-1">
						<span>{@html furigana}</span>
						<span class="text-sm">{meaning}</span>
					</div>

					<button
						on:click={async () => {
							await convertTextToSpeech(sentence);

							if (audioElement) audioElement.play();
						}}
					>
						<Volume2 class="size-5" />
					</button>
				</div>
			{/each}
		{:else}
			<p>Loading...</p>
		{/if}
	</Tabs.Content>
</Tabs.Root>

{#if activeTab === 'sentence'}
	<Select.Root
		selected={selectedValue}
		onSelectedChange={async (item) => {
			selectedValue = {
				value: item?.value,
				label: item?.label
			};
			await generateExampleSentences();
		}}
	>
		<Select.Trigger
			class="flashcard-completion-btn absolute bottom-3 right-1/2 flex w-[180px] translate-x-1/2 gap-2 bg-white text-black"
		>
			<Select.Value />
		</Select.Trigger>
		<Select.Content class="flashcard-completion-btn">
			{#if !conjugationData?.error}
				{#each [wordFlashcard?.name, ...Object.values(conjugationData)] as conjugation}
					<Select.Item value={conjugation}>
						{conjugation}
					</Select.Item>
				{/each}
			{:else}
				<Select.Item value={wordFlashcard?.name}>{wordFlashcard?.name}</Select.Item>
			{/if}
		</Select.Content>
	</Select.Root>
{/if}
