<script lang="ts">
	import { clickedEditFlashcard, currentFlashcardTypeStore } from '$lib/utils/stores';
	import * as Select from '$lib/components/ui/select';
	import { Input } from '$lib/components/ui/input';
	import { Textarea } from '$lib/components/ui/textarea';
	import { HelpCircle } from 'lucide-svelte';
	import * as Form from '$lib/components/ui/form';
	import { type FlashcardSchema } from '$lib/utils/zodSchema';
	import { type SuperForm, type Infer } from 'sveltekit-superforms';
	import { getContext } from 'svelte';
	import { isDesktop } from '$lib/utils';
	import { page } from '$app/stores';
	import ResponsiveTooltip from '$lib/components/responsive-tooltip.svelte';

	let form: SuperForm<Infer<FlashcardSchema>> = getContext('flashcardForm');

	const { form: formData, enhance } = form;

	function handleInput(event: Event, field: string) {
		const target = event.target as HTMLInputElement | HTMLTextAreaElement;
		$formData[field] = target.value;
	}

	$: selected = {
		value: $formData.type,
		label: $formData.type,
	};

	$: selectedPartOfSpeech = {
		value: $formData.partOfSpeech,
		label: $formData.partOfSpeech,
	};
</script>

<form method="POST" action="?/delete" use:enhance class="quiz-form w-full max-md:px-4">
	<div class="mb-auto flex flex-col gap-2">
		<Form.Field {form} name="name">
			<Form.Control let:attrs>
				<Form.Label class="mb-2 flex items-center gap-2">
					Name

					<ResponsiveTooltip tabindex={-1}>
						<span slot="trigger">
							<HelpCircle class="size-4 transition-transform hover:scale-125" />
						</span>
						<div class="max-w-xs text-sm">
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
					</ResponsiveTooltip>
				</Form.Label>

				{#if $isDesktop}
					<Input bind:value={$formData.name} {...attrs} />
				{:else}
					<Input value={$formData.name} on:change={(e) => handleInput(e, 'name')} {...attrs} />
				{/if}
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

		{#if $page.data.user.id === $formData.user || $page.data.isAdmin}
			<Form.Field {form} name="partOfSpeech">
				<Form.Control let:attrs>
					<Form.Label class="flex items-center gap-2">
						Part of speech

						<ResponsiveTooltip>
							<span slot="trigger">
								<HelpCircle class="size-4 transition-transform hover:scale-125" />
							</span>
							<div class="max-w-xs text-sm">
								<p>
									Part of speech is the type of the flashcard. It can be adjective, verb, unknown,
									etc. Useful for conjugations when the flashcard got classified wrong. Note: Only
									adjectives and verbs can be conjugated.
								</p>
							</div>
						</ResponsiveTooltip>
					</Form.Label>
					<Select.Root
						selected={selectedPartOfSpeech}
						onSelectedChange={(v) => {
							v && ($formData.partOfSpeech = v.value);
						}}
					>
						<Select.SelectTrigger {...attrs}>
							<Select.Value />
						</Select.SelectTrigger>
						<Select.Content>
							<Select.Item value="adjective" label="adjective">adjective</Select.Item>
							<Select.Item value="verb" label="verb">verb</Select.Item>
							<Select.Item value="unknown" label="unknown">unknown</Select.Item>
						</Select.Content>
					</Select.Root>
					<input hidden bind:value={$formData.partOfSpeech} name={attrs.name} />
				</Form.Control>
				<Form.FieldErrors />
			</Form.Field>
		{/if}

		<Form.Field {form} name="meaning">
			<Form.Control let:attrs>
				<Form.Label>Meaning</Form.Label>

				{#if $isDesktop}
					<Input {...attrs} bind:value={$formData.meaning} />
				{:else}
					<Input
						{...attrs}
						value={$formData.meaning}
						on:change={(e) => handleInput(e, 'meaning')}
					/>
				{/if}
			</Form.Control>
			<Form.FieldErrors />
		</Form.Field>

		{#if $currentFlashcardTypeStore !== 'kanji'}
			<Form.Field {form} name="romaji">
				<Form.Control let:attrs>
					<Form.Label>Romaji/Furigana</Form.Label>
					{#if $isDesktop}
						<Input {...attrs} bind:value={$formData.romaji} />
					{:else}
						<Input
							{...attrs}
							value={$formData.romaji}
							on:change={(e) => handleInput(e, 'romaji')}
						/>
					{/if}
				</Form.Control>
				<Form.FieldErrors />
			</Form.Field>
		{/if}

		<Form.Field {form} name="notes">
			<Form.Control let:attrs>
				<Form.Label>Notes</Form.Label>

				{#if $isDesktop}
					<Textarea {...attrs} class="resize-none" bind:value={$formData.notes} />
				{:else}
					<Textarea
						{...attrs}
						class="resize-none"
						value={$formData.notes}
						on:change={(e) => handleInput(e, 'notes')}
					/>
				{/if}
			</Form.Control>
			<Form.FieldErrors />
		</Form.Field>

		<input type="hidden" name="id" value={$formData.id} />
	</div>

	{#if $clickedEditFlashcard}
		<button formaction="?/update" class="w-full">
			<slot name="update" />
		</button>
	{:else}
		<button formaction="?/add" class="w-full">
			<slot name="add" />
		</button>
	{/if}
</form>
