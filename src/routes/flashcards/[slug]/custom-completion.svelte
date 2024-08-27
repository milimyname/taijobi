<script lang="ts">
	import * as Tabs from '$lib/components/ui/tabs';
	import { WholeWord, Text, Scroll, Volume2 } from 'lucide-svelte';
	import type { FlashcardType } from '$lib/utils/ambient.d.ts';
	import { cn, isDesktop } from '$lib/utils';
	import * as DrawerDialog from '$lib/components/ui/drawer-dialog';
	import Button from '$lib/components/ui/button/button.svelte';
	import { showCustomContent } from '$lib/utils/stores';
	import { toast } from 'svelte-sonner';

	export let wordFlashcard: FlashcardType | undefined;

	type ResponseType = { kana: string; kanji: string; english: string; furigana: string };

	let audioSource: string = '';
	let audioElement: HTMLAudioElement;
	let loadingStates = new Map();
	let activeTab: string | undefined = wordFlashcard?.notes ? 'note' : 'sentence';
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
						positive: {
							plain: 'Affirmative',
						},
						negative: {
							plain: 'Negative',
						},
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

	async function generateAISentences() {
		loadingStates.set('ai-sentences', true);
		loadingStates = loadingStates; // Trigger reactivity
		try {
			// Check if there are no examples, call openai to get examples
			const res = await fetch('/api/openai', {
				method: 'POST',
				headers: {
					'Content-Type': 'application/json',
				},
				body: JSON.stringify({ input: wordFlashcard?.name, type: 'text' }),
			});

			const newExamples = await res.json();

			if (newExamples.length === 0) throw new Error('No examples found');

			if (!newExamples[0]?.furigana) {
				toast.error(
					'No examples found. Please try again or leave a feedback by clicking the 🐞 above.',
				);

				return;
			}

			examples = [...newExamples, ...examples];

			toast.success('New examples generated successfully');
		} catch (e) {
			console.error(e);
		} finally {
			loadingStates.set('ai-sentences', false);
			loadingStates = loadingStates; // Trigger reactivity
		}
	}

	async function convertTextToSpeech(input: string, index: number) {
		loadingStates.set(index, true);
		loadingStates = loadingStates; // Trigger reactivity

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

		loadingStates.set(index, false);
		loadingStates = loadingStates; // Trigger reactivity
	}

	function onOutsideClickDrawer() {
		activeTab = wordFlashcard?.notes ? 'note' : 'sentence';
		if ($isDesktop) return ($showCustomContent = false);

		setTimeout(() => ($showCustomContent = false), 100);
	}

	$: if ($showCustomContent && (activeTab === 'conjugation' || wordFlashcard)) conjugate();

	$: if ($showCustomContent && activeTab === 'sentence' && wordFlashcard)
		generateExampleSentences();

	$: if ($showCustomContent && wordFlashcard) examples = [];

	$: conjguationDisabled = conjugationData?.error || wordFlashcard?.partOfSpeech === 'unknown';
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
			'fixed bottom-0 left-0 right-0 max-h-[96%]',
			$isDesktop && 'left-1/2 w-fit max-w-3xl',
		)}
	>
		<div class="-mt-2 overflow-y-scroll">
			<Tabs.Root value={activeTab} onValueChange={(v) => (activeTab = v)}>
				<div class="sticky top-0 mx-auto flex w-fit items-center">
					<Tabs.List>
						<Tabs.Trigger value="note" disabled={!wordFlashcard?.notes}>
							<Scroll class="size-5" />
						</Tabs.Trigger>
						<Tabs.Trigger value="conjugation" disabled={conjguationDisabled}>
							<WholeWord class="size-5" />
						</Tabs.Trigger>
						<Tabs.Trigger value="sentence">
							<Text class="size-5" />
						</Tabs.Trigger>
					</Tabs.List>

					{#if activeTab === 'sentence'}
						<Button
							variant="outline"
							on:click={() => generateAISentences()}
							loading={loadingStates.get('ai-sentences')}
						>
							New
						</Button>
					{/if}
				</div>
				<Tabs.Content value="note" class="px-5">{wordFlashcard?.notes}</Tabs.Content>
				<Tabs.Content value="conjugation" class="px-5">
					{#if conjugationData && !conjugationData?.error}
						<div class={cn(!conjugationData?.error && 'grid grid-cols-3 gap-1 sm:gap-2')}>
							{#each conjugationData as data, i}
								<p class="lg:text-md text-[10px]">{data?.name}</p>

								{#if data?.positive?.furigana}
									<p
										class={cn(
											'lg:text-md text-[10px]',
											i !== 0 && 'text-sm font-semibold lg:text-lg',
										)}
									>
										{@html data?.positive?.furigana}
									</p>
								{:else}
									<p
										class={cn(
											'lg:text-md text-[10px]',
											i !== 0 && 'text-sm font-semibold lg:text-lg',
										)}
									>
										{data?.positive?.plain}
									</p>
								{/if}
								{#if data?.negative?.furigana}
									<p
										class={cn(
											'lg:text-md text-[10px]',
											i !== 0 && 'text-sm font-semibold lg:text-lg',
										)}
									>
										{@html data?.negative?.furigana}
									</p>
								{:else}
									<p
										class={cn(
											'lg:text-md text-[10px]',
											i !== 0 && 'text-sm font-semibold lg:text-lg',
										)}
									>
										{data?.negative?.plain}
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
						{#each examples as { furigana, kanji, english }, index}
							<div class="grid grid-cols-[1fr_20px] gap-2">
								<div class="space-y-2">
									<p class="break-all text-lg lg:text-2xl">{@html furigana}</p>
									<p class="text-sm">{english}</p>
								</div>

								<Button
									variant="none"
									size="icon"
									loading={loadingStates.get(index)}
									class="p-0"
									on:click={async () => {
										await convertTextToSpeech(kanji, index);

										if (audioElement) audioElement.play();
									}}
								>
									<Volume2 class="size-5 " />
								</Button>
							</div>
						{/each}
					{:else}
						<p>Loading...</p>
					{/if}
				</Tabs.Content>
			</Tabs.Root>
			<DrawerDialog.Footer className="md:hidden sticky bottom-0">
				<DrawerDialog.Close asChild let:builder>
					<Button builders={[builder]} variant="outline">Cancel</Button>
				</DrawerDialog.Close>
			</DrawerDialog.Footer>
		</div>
	</DrawerDialog.Content>
</DrawerDialog.Root>
