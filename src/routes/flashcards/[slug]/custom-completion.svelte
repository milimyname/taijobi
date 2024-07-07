<script lang="ts">
	import * as Tabs from '$lib/components/ui/tabs';
	import { WholeWord, Text, Scroll, Volume2 } from 'lucide-svelte';
	import type { FlashcardType } from '$lib/utils/ambient.d.ts';
	import { cn, isDesktop } from '$lib/utils';
	import * as DrawerDialog from '$lib/components/ui/drawerDialog';
	import Button from '$lib/components/ui/button/button.svelte';
	import { showCustomContent } from '$lib/utils/stores';
	import { toast } from 'svelte-sonner';

	export let wordFlashcard: FlashcardType | undefined;

	type ResponseType = { kana: string; kanji: string; english: string; furigana: string };

	let audioSource: string = '';
	let audioElement: HTMLAudioElement;
	let activeTab: string | undefined = wordFlashcard?.notes ? 'note' : 'conjugation';
	let conjugationData: any;
	let examples: ResponseType[] = [];

	async function conjugate() {
		try {
			const res = await fetch(`/api/conjugation`, {
				method: 'POST',
				headers: {
					'Content-Type': 'application/json',
				},
				body: JSON.stringify({
					word: wordFlashcard?.name,
				}),
			});

			if (!res.ok) throw new Error('Failed to fetch word flashcard');
			const data = await res.json();

			// Verb conjugation
			if (Array.isArray(data)) {
				conjugationData = [
					{
						name: '',
						positive: 'Affirmative',
						negative: 'Negative',
					},
					...data,
				];
				return;
			}

			// Adjective conjugation
			conjugationData = data;
		} catch (e) {
			console.error(e);
		}
	}

	async function generateExampleSentences() {
		try {
			const res = await fetch('/api/jisho', {
				method: 'POST',
				headers: {
					'Content-Type': 'application/json',
				},
				body: JSON.stringify({
					input: wordFlashcard?.name,
				}),
			});

			if (!res.ok) throw new Error('Failed to fetch sentence examples');

			const data: ResponseType[] = await res.json();

			if (data.length === 0) throw new Error('No examples found');

			// Check if examples are repeated, don't add them
			if (examples.length !== 0) {
				const filteredData = data.filter((d) => !examples.some((e) => e.english === d.english));
				examples = [...examples, ...filteredData];
				return;
			}

			examples = [...examples, ...data];
		} catch (e) {
			console.error(e);
			toast.error(
				'No examples found. Please try again or leave a feedback by clicking the 🐞 above. PS: Only words can have examples',
			);
		}
	}

	async function convertTextToSpeech(input: string) {
		try {
			const res = await fetch('/api/openai', {
				method: 'POST',
				headers: {
					'Content-Type': 'application/json',
				},
				body: JSON.stringify({ input, type: 'audio' }),
			});

			if (!res.ok) throw new Error('Failed to fetch audio');

			const data = await res.json();

			const audioData = data.audioData;

			audioSource = `data:audio/mp3;base64,${audioData}`;
		} catch (e) {
			console.error(e);
		}
	}

	function onOutsideClickDrawer() {
		if ($isDesktop) return ($showCustomContent = false);

		setTimeout(() => ($showCustomContent = false), 100);
	}

	$: if ($showCustomContent && (activeTab === 'conjugation' || wordFlashcard)) conjugate();

	$: if (activeTab === 'sentence' && wordFlashcard) generateExampleSentences();

	$: if (wordFlashcard?.notes === '') activeTab = 'conjugation';

	$: if (wordFlashcard) examples = [];

	$: if (wordFlashcard?.type !== 'word' && activeTab === 'conjugation') activeTab = 'sentence';
</script>

{#if audioSource}
	<audio src={audioSource} bind:this={audioElement} />
{/if}

<DrawerDialog.Root
	open={$showCustomContent}
	onOutsideClick={onOutsideClickDrawer}
	onClose={onOutsideClickDrawer}
>
	<DrawerDialog.Content
		class={cn(
			'fixed bottom-0 left-0 right-0 max-h-[96%] w-full',
			$isDesktop && 'left-1/2  min-w-fit max-w-2xl',
		)}
	>
		<div class="-mt-2 flex w-full flex-col overflow-y-auto">
			<Tabs.Root value={activeTab} onValueChange={(v) => (activeTab = v)}>
				<Tabs.List class="sticky top-0 mx-auto flex w-fit">
					<Tabs.Trigger value="note" disabled={!wordFlashcard?.notes}>
						<Scroll class="size-5" />
					</Tabs.Trigger>
					<Tabs.Trigger
						value="conjugation"
						disabled={conjugationData?.error || wordFlashcard?.type !== 'word'}
					>
						<WholeWord class="size-5" />
					</Tabs.Trigger>
					<Tabs.Trigger value="sentence">
						<Text class="size-5" />
					</Tabs.Trigger>
				</Tabs.List>
				<Tabs.Content value="note" class="px-5">{wordFlashcard?.notes}</Tabs.Content>
				<Tabs.Content value="conjugation" class="px-5">
					{#if conjugationData && !conjugationData?.error}
						<div class={cn(!conjugationData?.error && 'grid grid-cols-3 gap-1 sm:gap-2')}>
							{#each conjugationData as data, i}
								<p class="lg:text-md text-[10px]">{data?.name}</p>

								{#if data?.positive_furigana}
									<p
										class={cn(
											'lg:text-md text-[10px]',
											i !== 0 && 'text-sm font-semibold lg:text-lg',
										)}
									>
										{@html data?.positive_furigana}
									</p>
								{:else}
									<p
										class={cn(
											'lg:text-md text-[10px]',
											i !== 0 && 'text-sm font-semibold lg:text-lg',
										)}
									>
										{data?.positive}
									</p>
								{/if}
								{#if data?.negative_furigana}
									<p
										class={cn(
											'lg:text-md text-[10px]',
											i !== 0 && 'text-sm font-semibold lg:text-lg',
										)}
									>
										{@html data?.negative_furigana}
									</p>
								{:else}
									<p
										class={cn(
											'lg:text-md text-[10px]',
											i !== 0 && 'text-sm font-semibold lg:text-lg',
										)}
									>
										{data?.negative}
									</p>
								{/if}
							{/each}
						</div>
					{:else}
						<p>Loading...</p>
					{/if}
				</Tabs.Content>
				<Tabs.Content value="sentence" class="space-y-5 px-5 pb-14">
					{#if examples.length !== 0}
						{#each examples as { furigana, kanji, english }}
							<div class="grid grid-cols-[1fr_20px] items-start gap-2">
								<div class="space-y-2">
									<p class="text-lg lg:text-2xl">{@html furigana}</p>
									<p class="text-sm">{english}</p>
								</div>

								<button
									class="mt-2.5"
									on:click={async () => {
										await convertTextToSpeech(kanji);

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
			<DrawerDialog.Footer className="md:hidden">
				<DrawerDialog.Close asChild let:builder>
					<Button builders={[builder]} variant="outline">Cancel</Button>
				</DrawerDialog.Close>
			</DrawerDialog.Footer>
		</div>
	</DrawerDialog.Content>
</DrawerDialog.Root>
