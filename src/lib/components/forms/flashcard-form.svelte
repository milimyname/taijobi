<script lang="ts">
	import {
		clickedEditFlashcard,
		currentFlashcardTypeStore,
		clickedAddFlashcardCollection,
	} from '$lib/utils/stores';
	import * as Select from '$lib/components/ui/select';
	import { Input } from '$lib/components/ui/input';
	import { Textarea } from '$lib/components/ui/textarea';
	import { fly } from 'svelte/transition';
	import { quintOut } from 'svelte/easing';
	import { HelpCircle } from 'lucide-svelte';
	import * as Form from '$lib/components/ui/form';
	import { type FlashcardSchema } from '$lib/utils/zodSchema';
	import { type SuperForm, type Infer } from 'sveltekit-superforms';
	import { cn, isDesktop } from '$lib/utils';

	export let form: SuperForm<Infer<FlashcardSchema>>;

	let showInfo = false;

	const { form: formData, enhance } = form;

	$: selected = {
		value: $formData.type,
		label: $formData.type,
	};
</script>

<form
	method="POST"
	use:enhance
	class={cn('quiz-form z-[1000] flex w-full flex-col', !$isDesktop && 'px-4')}
>
	<div class="mb-auto flex flex-col gap-2">
		<Form.Field {form} name="name">
			<Form.Control let:attrs>
				<Form.Label class="mb-2 flex items-center gap-2">
					Name
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
								easing: quintOut,
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
				<Input {...attrs} bind:value={$formData.name} />
			</Form.Control>
			<Form.FieldErrors />
		</Form.Field>

		<Form.Field {form} name="type">
			<Form.Control let:attrs>
				<Form.Label>Type</Form.Label>
				<Select.Root
					{selected}
					onSelectedChange={(v) => {
						v && ($formData.type = v.value);
					}}
				>
					<Select.SelectTrigger {...attrs}>
						<Select.Value />
					</Select.SelectTrigger>
					<Select.Content>
						{#if $currentFlashcardTypeStore === 'kanji'}
							<Select.Item value={$currentFlashcardTypeStore} label="kanji">
								{$currentFlashcardTypeStore}
							</Select.Item>
						{:else}
							<Select.Item value="word" label="word">word</Select.Item>
							<Select.Item value="phrase" label="phrase">phrase</Select.Item>
						{/if}
					</Select.Content>
				</Select.Root>
				<input hidden bind:value={$formData.type} name={attrs.name} />
			</Form.Control>
			<Form.FieldErrors />
		</Form.Field>

		<Form.Field {form} name="meaning">
			<Form.Control let:attrs>
				<Form.Label>Meaning</Form.Label>
				<Input {...attrs} bind:value={$formData.meaning} />
			</Form.Control>
			<Form.FieldErrors />
		</Form.Field>

		{#if $currentFlashcardTypeStore !== 'kanji'}
			<Form.Field {form} name="romanji">
				<Form.Control let:attrs>
					<Form.Label>Romanji/Furigana</Form.Label>
					<Input {...attrs} bind:value={$formData.romanji} />
				</Form.Control>
				<Form.FieldErrors />
			</Form.Field>
		{/if}

		<Form.Field {form} name="notes">
			<Form.Control let:attrs>
				<Form.Label>Notes</Form.Label>
				<Textarea {...attrs} class="resize-none" bind:value={$formData.notes} />
			</Form.Control>
			<Form.FieldErrors />
		</Form.Field>

		<input type="hidden" name="id" bind:value={$formData.id} />
	</div>

	{#if !$clickedEditFlashcard && $clickedAddFlashcardCollection}
		<button formaction="?/add" class="cursor-not-allowed">
			<slot name="add" />
		</button>
	{:else if $clickedEditFlashcard}
		<div class="grid grid-cols-3 gap-2">
			<button formaction="?/delete">
				<slot name="delete" />
			</button>

			<button formaction="?/update" class="col-span-2 cursor-not-allowed">
				<slot name="update" />
			</button>
		</div>
	{:else}
		<button formaction="?/add">
			<slot name="add" />
		</button>
	{/if}
</form>
