<script lang="ts">
	import {
		clickedEditFlashcard,
		currentFlashcardTypeStore,
		clickedAddFlashcardCollection
	} from '$lib/utils/stores';
	import { fly } from 'svelte/transition';
	import { quintOut } from 'svelte/easing';
	import { HelpCircle } from 'lucide-svelte';
	import { cn, isDesktop } from '$lib/utils';
	import * as Form from '$lib/components/ui/form';
	import { flashcardSchema, type FlashcardSchema } from '$lib/utils/zodSchema';
	import { type SuperForm } from 'sveltekit-superforms/client';

	export let form: SuperForm<FlashcardSchema>;

	let showInfo = false;

	let selectedItems = {
		value: '',
		label: ''
	};

	$: if ($clickedEditFlashcard)
		selectedItems = {
			value: $currentFlashcardTypeStore,
			label: $currentFlashcardTypeStore
		};
</script>

<Form.Root
	method="POST"
	{form}
	controlled
	schema={flashcardSchema}
	let:config
	class={cn('quiz-form z-[1000] flex w-full flex-col rounded-t-2xl', !$isDesktop && 'px-4')}
>
	<div class="mb-auto flex flex-col gap-2">
		<Form.Field {config} name="name">
			<Form.Item>
				<Form.Label class="mb-2 flex items-center gap-2">
					Flashcard
					<button
						type="button"
						on:click={() => (showInfo = true)}
						on:mouseenter={() => (showInfo = true)}
						on:mouseleave={() => (showInfo = false)}
						class="relative hover:fill-black/50"
					>
						<HelpCircle class="size-4 transition-transform hover:scale-125" />
					</button>

					{#if showInfo}
						<div
							transition:fly={{
								delay: 0,
								duration: 1000,
								opacity: 0,
								y: 1000,
								easing: quintOut
							}}
							class="z-2 absolute bottom-0 left-0 h-2/3 w-full rounded-md bg-blue-200 p-4 text-black"
						>
							<p>If you wanna use custom furigana, please use the following format:</p>
							<ul class="my-2 text-xl">
								<li>
									<code class="text-black">漢字/かんじ/</code>
								</li>
								<li>
									<code class="text-black">読/よ/み物/もの/</code>
								</li>
							</ul>
							<p>
								Mostly, u won't need to use it but sometimes, there is a typo in the auto furigana
								and u can overwrite it with this. Just use slashes for hiragana after the last kanji
								one and don't forget to close it with a slash
							</p>
						</div>
					{/if}
				</Form.Label>
				<Form.Input />
				<Form.Validation />
			</Form.Item>
		</Form.Field>

		<Form.Field {config} name="type">
			<Form.Item>
				<Form.Label>Type</Form.Label>
				<Form.Select selected={selectedItems}>
					<Form.SelectTrigger />
					<Form.SelectContent>
						{#if $currentFlashcardTypeStore === 'kanji'}
							<Form.SelectItem value={$currentFlashcardTypeStore}>
								{$currentFlashcardTypeStore}
							</Form.SelectItem>
						{:else}
							<Form.SelectItem value="word">word</Form.SelectItem>
							<Form.SelectItem value="phrase">phrase</Form.SelectItem>
						{/if}
					</Form.SelectContent>
				</Form.Select>
				<Form.Validation />
			</Form.Item>
		</Form.Field>

		<Form.Field {config} name="meaning">
			<Form.Item>
				<Form.Label>Meaning</Form.Label>
				<Form.Input />
				<Form.Validation />
			</Form.Item>
		</Form.Field>

		{#if $currentFlashcardTypeStore !== 'kanji'}
			<Form.Field {config} name="romanji">
				<Form.Item>
					<Form.Label>Romanji/Furigana</Form.Label>
					<Form.Input />
					<Form.Validation />
				</Form.Item>
			</Form.Field>
		{/if}

		<Form.Field {config} name="notes">
			<Form.Item>
				<Form.Label>Notes</Form.Label>
				<Form.Textarea class="resize-none" />
				<Form.Validation />
			</Form.Item>
		</Form.Field>

		<Form.Field {config} name="id">
			<Form.Item>
				<Form.Input type="hidden" />
			</Form.Item>
		</Form.Field>
	</div>

	{#if $clickedEditFlashcard}
		<div class={cn('grid grid-cols-3 flex-col gap-2', !$isDesktop && 'flex-col')}>
			<button formaction="?/delete">
				<slot name="delete" />
			</button>

			<button formaction="?/update" class="col-span-2">
				<slot name="update" />
			</button>
		</div>
	{:else}
		<button formaction="?/add">
			<slot name="add" />
		</button>
	{/if}
</Form.Root>
