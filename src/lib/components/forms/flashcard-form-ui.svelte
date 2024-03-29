<script lang="ts">
	import {
		clickedEditFlashcard,
		clickedAddFlashcardCollection,
		currentFlashcardTypeStore,
		clickedFeedback
	} from '$lib/utils/stores';
	import * as Select from '$lib/components/ui/select';
	import * as Dialog from '$lib/components/ui/dialog';
	import * as Drawer from '$lib/components/ui/drawer';
	import { Input } from '$lib/components/ui/input';
	import { Button } from '$lib/components/ui/button';
	import { Textarea } from '$lib/components/ui/textarea';
	import { isDesktop, cn } from '$lib/utils';
	import { fly } from 'svelte/transition';
	import { quintOut } from 'svelte/easing';
	import { HelpCircle } from 'lucide-svelte';
	import * as Form from '$lib/components/ui/form';
	import { type FlashcardSchema } from '$lib/utils/zodSchema';
	import { type SuperForm, type Infer } from 'sveltekit-superforms';

	export let form: SuperForm<Infer<FlashcardSchema>>;

	let showInfo = false;

	const { form: formData, enhance, errors } = form;

	const onOutsideClick = () => {
		setTimeout(() => {
			$clickedAddFlashcardCollection = false;
			$clickedEditFlashcard = false;
			form.reset();
		}, 100);
	};

	$: if ($clickedFeedback) {
		$clickedAddFlashcardCollection = false;
		$clickedEditFlashcard = false;
	}

	$: selected = {
		value: $formData.type,
		label: $formData.type
	};

	$: open = $clickedAddFlashcardCollection || $clickedEditFlashcard;
</script>

{#if $isDesktop}
	<Dialog.Root bind:open {onOutsideClick}>
		<Dialog.Content class="z-[100] sm:max-w-[425px]">
			<Dialog.Header>
				<Dialog.Title>
					{#if $clickedEditFlashcard}
						Update flashcard
					{:else}
						Add a new flashcard
					{/if}
				</Dialog.Title>
			</Dialog.Header>
			<form method="POST" use:enhance class="quiz-form z-[1000] flex w-full flex-col rounded-t-2xl">
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
											Mostly, u won't need to use it but sometimes, there is a typo in the auto
											furigana and u can overwrite it with this. Just use slashes for hiragana after
											the last kanji one and don't forget to close it with a slash
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

					<Form.Field {form} name="id">
						<Form.Control let:attrs>
							<Input {...attrs} type="hidden" bind:value={$formData.id} />
						</Form.Control>
					</Form.Field>
				</div>

				{#if $clickedEditFlashcard}
					<div class="grid grid-cols-3 gap-2">
						<Form.Button variant="destructive" formaction="?/delete">Delete</Form.Button>

						<Form.Button
							class="col-span-2"
							formaction="?/update"
							disabled={($errors.name && $errors.name.length > 0) ||
								($errors.type && $errors.type.length > 0)}
						>
							Update
						</Form.Button>
					</div>
				{:else}
					<Form.Button formaction="?/add" class="w-full">Add</Form.Button>
				{/if}
			</form>
		</Dialog.Content>
	</Dialog.Root>
{:else}
	<Drawer.Root onClose={onOutsideClick} {open} {onOutsideClick}>
		<Drawer.Portal>
			<Drawer.Content class="fixed bottom-0 left-0 right-0 max-h-[96%]">
				<div class="flex w-full flex-col overflow-auto">
					<Drawer.Header class="text-left">
						<Drawer.Title>
							{#if $clickedEditFlashcard}
								Update flashcard
							{:else}
								Add a new flashcard
							{/if}
						</Drawer.Title>
					</Drawer.Header>
					<form
						method="POST"
						use:enhance
						class="quiz-form z-[1000] flex w-full flex-col overflow-auto px-4"
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
													Mostly, u won't need to use it but sometimes, there is a typo in the auto
													furigana and u can overwrite it with this. Just use slashes for hiragana
													after the last kanji one and don't forget to close it with a slash
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

							<Form.Field {form} name="id">
								<Form.Control let:attrs>
									<Input {...attrs} type="hidden" bind:value={$formData.id} />
								</Form.Control>
							</Form.Field>
						</div>

						{#if $clickedEditFlashcard}
							<div class="grid grid-cols-3 flex-col gap-2">
								<button formaction="?/delete">
									<Drawer.Close asChild let:builder>
										<Form.Button builders={[builder]} variant="destructive" class="w-full">
											Delete
										</Form.Button>
									</Drawer.Close>
								</button>

								<button
									formaction="?/update"
									class={cn('col-span-2', ($errors.name || $errors.type) && 'cursor-not-allowed')}
								>
									<Drawer.Close asChild let:builder>
										<Form.Button
											builders={[builder]}
											class="w-full"
											disabled={($errors.name && $errors.name.length > 0) ||
												($errors.type && $errors.type.length > 0)}
										>
											Update
										</Form.Button>
									</Drawer.Close>
								</button>
							</div>
						{:else}
							<button formaction="?/add" class="col-span-2 cursor-not-allowed">
								<Drawer.Close asChild let:builder>
									<Form.Button
										builders={[builder]}
										class="w-full"
										disabled={$formData.name === '' || $formData.type === ''}
									>
										Add
									</Form.Button>
								</Drawer.Close>
							</button>
						{/if}
					</form>
					<Drawer.Footer>
						<Drawer.Close asChild let:builder>
							<Button builders={[builder]} variant="outline">Cancel</Button>
						</Drawer.Close>
					</Drawer.Footer>
				</div>
			</Drawer.Content>
		</Drawer.Portal>
	</Drawer.Root>
{/if}
