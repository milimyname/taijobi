<script lang="ts">
	import {
		clickedEditFlashcard,
		clickedAddFlashcardCollection,
		clickedAddFlahcardBox,
		clickedFeedback,
		maxFlashcards,
		flashcardBoxes,
		swapFlashcards,
		selectQuizItemsForm,
		selectedQuizItems,
		currentBoxId,
		currentFlashcardCollectionId
	} from '$lib/utils/stores';
	import QuizItems from './quiz-items.svelte';
	import { Input } from '$lib/components/ui/input';
	import { Textarea } from '$lib/components/ui/textarea';
	import * as Dialog from '$lib/components/ui/dialog';
	import * as Drawer from '$lib/components/ui/drawer';
	import { Button } from '$lib/components/ui/button';
	import { cn, isDesktop } from '$lib/utils';
	import { page } from '$app/stores';
	import { type FlashcardCollectionSchema } from '$lib/utils/zodSchema';
	import { type SuperForm, type Infer } from 'sveltekit-superforms';
	import * as Form from '$lib/components/ui/form';

	export let form: SuperForm<Infer<FlashcardCollectionSchema>>;

	const { form: formData, enhance, errors } = form;

	function onClose() {
		$clickedAddFlashcardCollection = false;
		$clickedAddFlahcardBox = false;
		$clickedEditFlashcard = false;
		$selectedQuizItems = [];
		form.reset();
	}

	function onOutsideClick(e: PointerEvent | MouseEvent | TouchEvent) {
		let eventTarget = (
			(e as TouchEvent).changedTouches ? (e as TouchEvent).changedTouches[0].target : e.target
		) as Element;

		// If the user clicks on the leave button, don't move the card
		if (
			($page.url.pathname.includes('flashcards') && eventTarget.closest('.add-btn')) ||
			eventTarget.closest('.swap-items') ||
			eventTarget.closest('.edit-collection-btn')
		)
			return;

		onClose();
	}

	$: open = $clickedAddFlashcardCollection || $clickedAddFlahcardBox;

	$: if ($clickedFeedback) {
		$clickedAddFlashcardCollection = false;
		$clickedAddFlahcardBox = false;
		$clickedEditFlashcard = false;
	}
</script>

{#if $isDesktop}
	<Dialog.Root bind:open={$swapFlashcards}>
		<Dialog.Content class="swap-items z-[101] h-1/2 max-w-2xl p-0">
			<QuizItems flashcardBox={$currentBoxId}>
				<Dialog.Close asChild let:builder>
					<Button
						builders={[builder]}
						on:click={() => {
							$selectQuizItemsForm = false;
							$swapFlashcards = false;
							$selectedQuizItems = [];
						}}
						variant="outline"
					>
						Cancel
					</Button>
				</Dialog.Close>
			</QuizItems>
		</Dialog.Content>
	</Dialog.Root>

	<Dialog.Root bind:open {onOutsideClick}>
		<Dialog.Content class="z-[100] sm:max-w-[425px]">
			<Dialog.Header class="flex flex-row items-center">
				<Dialog.Title>
					{#if $clickedEditFlashcard}
						Edit {$clickedAddFlashcardCollection ? 'collection' : 'box'}
					{:else}
						Add a new {$clickedAddFlashcardCollection ? 'collection' : 'box'}
					{/if}
				</Dialog.Title>
				{#if !$clickedAddFlashcardCollection && $maxFlashcards !== '0' && $flashcardBoxes.length > 1}
					<button class="ml-auto mr-5 text-sm underline" on:click={() => ($swapFlashcards = true)}>
						Swap
					</button>
				{/if}
			</Dialog.Header>
			<form
				method="POST"
				use:enhance
				class="quiz-form z-[1000] mb-auto flex w-full flex-col gap-2 rounded-t-2xl"
			>
				<Form.Field {form} name="name">
					<Form.Control let:attrs>
						<Form.Label>Name</Form.Label>
						<Input {...attrs} bind:value={$formData.name} />
					</Form.Control>
					<Form.FieldErrors />
				</Form.Field>

				<Form.Field {form} name="description">
					<Form.Control let:attrs>
						<Form.Label>Description</Form.Label>
						<Textarea {...attrs} class="resize-none" bind:value={$formData.description} />
					</Form.Control>
					<Form.FieldErrors />
				</Form.Field>

				<input type="hidden" name="id" bind:value={$formData.id} />

				<input
					type="hidden"
					name="flashcardCollection"
					bind:value={$currentFlashcardCollectionId}
				/>

				{#if $clickedEditFlashcard}
					<div class="grid grid-cols-3 gap-2">
						<Form.Button variant="destructive" formaction="?/delete">Delete</Form.Button>

						<Form.Button class="col-span-2" formaction="?/update" disabled={$formData.name === ''}>
							Update
						</Form.Button>
					</div>
				{:else}
					<Form.Button formaction="?/add" disabled={$formData.name === ''}>Add</Form.Button>
				{/if}
			</form>
		</Dialog.Content>
	</Dialog.Root>
{:else}
	<Drawer.Root {onClose} {open} {onOutsideClick}>
		<Drawer.Portal>
			<Drawer.Content class="fixed bottom-0 left-0 right-0 max-h-[96%]">
				<div class="flex w-full flex-col overflow-auto">
					<Drawer.Header class="flex items-center text-left">
						<Drawer.Title class="w-full">
							{#if $clickedEditFlashcard}
								Edit {$clickedAddFlashcardCollection ? 'collection' : 'box'}
							{:else}
								Add a new {$clickedAddFlashcardCollection ? 'collection' : 'box'}
							{/if}
						</Drawer.Title>

						{#if !$clickedAddFlashcardCollection && $maxFlashcards !== '0' && $flashcardBoxes.length > 1}
							<Drawer.Nested>
								<Drawer.Trigger
									class="w-min items-center text-sm underline"
									on:click={() => ($swapFlashcards = true)}
								>
									Swap
								</Drawer.Trigger>
								<Drawer.Portal>
									<Drawer.Content
										class="select-quiz fixed bottom-0 left-0 right-0 mt-24 flex h-full max-h-[94%] flex-col rounded-t-[10px] bg-gray-100"
									>
										<QuizItems flashcardBox={$currentBoxId}>
											<Drawer.Close asChild let:builder>
												<Button
													builders={[builder]}
													on:click={() => {
														$selectQuizItemsForm = false;
														$swapFlashcards = false;
														$selectedQuizItems = [];
													}}
													variant="outline"
												>
													Cancel
												</Button>
											</Drawer.Close>
										</QuizItems>
									</Drawer.Content>
								</Drawer.Portal>
							</Drawer.Nested>
						{/if}
					</Drawer.Header>
					<form method="POST" use:enhance class="quiz-form flex w-full flex-col px-4">
						<div class="mb-auto flex flex-col gap-2">
							<Form.Field {form} name="name">
								<Form.Control let:attrs>
									<Form.Label>Name</Form.Label>
									<Input {...attrs} bind:value={$formData.name} />
								</Form.Control>
								<Form.FieldErrors />
							</Form.Field>

							<Form.Field {form} name="description">
								<Form.Control let:attrs>
									<Form.Label>Description</Form.Label>
									<Textarea {...attrs} class="resize-none" bind:value={$formData.description} />
								</Form.Control>
								<Form.FieldErrors />
							</Form.Field>

							<input type="hidden" name="id" bind:value={$formData.id} />

							<input
								type="hidden"
								name="flashcardCollection"
								bind:value={$currentFlashcardCollectionId}
							/>
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
									class={cn('col-span-2', $errors.name && 'cursor-not-allowed')}
								>
									<Drawer.Close asChild let:builder>
										<Form.Button
											builders={[builder]}
											class="w-full"
											disabled={$errors.name && $errors.name.length > 0}
										>
											Update
										</Form.Button>
									</Drawer.Close>
								</button>
							</div>
						{:else}
							<button
								formaction="?/add"
								disabled={$formData.name === ''}
								class={cn($formData.name === '') && 'cursor-not-allowed'}
							>
								<Drawer.Close asChild let:builder>
									<Form.Button builders={[builder]} class="w-full" disabled={$formData.name === ''}>
										Add
									</Form.Button>
								</Drawer.Close>
							</button>
						{/if}
					</form>
					<Drawer.Footer class="h-fit">
						<Drawer.Close asChild let:builder>
							<Button builders={[builder]} variant="outline">Cancel</Button>
						</Drawer.Close>
					</Drawer.Footer>
				</div>
			</Drawer.Content>
		</Drawer.Portal>
	</Drawer.Root>
{/if}

<!-- <Drawer.Root {open}>
		<Drawer.Trigger asChild let:builder>
			<Button variant="outline" builders={[builder]}>Edit Profile</Button>
		</Drawer.Trigger>
		<Drawer.Content>
			<Drawer.Header class="text-left">
				<Drawer.Title>Edit profile</Drawer.Title>
				<Drawer.Description>
					Make changes to your profile here. Click save when you're done.
				</Drawer.Description>
			</Drawer.Header>
			<form class="grid items-start gap-4 px-4">
				<div class="grid gap-2">
					<label for="email">Email</label>
					<Input type="email" id="email" value="shadcn@example.com" />
				</div>
				<div class="grid gap-2">
					<label for="username">Username</label>
					<Input id="username" value="@shadcn" />
				</div>
				<div class="grid gap-2">
					<label for="email">Email</label>
					<Input type="email" id="email" value="shadcn@example.com" />
				</div>
				<div class="grid gap-2">
					<label for="username">Username</label>
					<Input id="username" value="@shadcn" />
				</div>
				<div class="grid gap-2">
					<label for="email">Email</label>
					<Input type="email" id="email" value="shadcn@example.com" />
				</div>
				<div class="grid gap-2">
					<label for="username">Username</label>
					<Input id="username" value="@shadcn" />
				</div>
				<Button type="submit">Save changes</Button>
			</form>
			<Drawer.Footer class="pt-2">
				<Drawer.Close asChild let:builder>
					<Button variant="outline" builders={[builder]}>Cancel</Button>
				</Drawer.Close>
			</Drawer.Footer>
		</Drawer.Content>
	</Drawer.Root> -->
