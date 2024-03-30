<script lang="ts">
	import {
		clickedQuizForm,
		selectQuizItemsForm,
		selectedQuizItems,
		swapFlashcards
	} from '$lib/utils/stores';
	import QuizItems from './quiz-items.svelte';
	import * as Dialog from '$lib/components/ui/dialog';
	import * as Drawer from '$lib/components/ui/drawer';
	import { Button } from '$lib/components/ui/button';
	import Form from '$lib/components/forms/quiz-form.svelte';
	import { isDesktop } from '$lib/utils';
	import { Grid2X2 } from 'lucide-svelte';
	import { type QuizSchema } from '$lib/utils/zodSchema';
	import { type SuperForm, type Infer } from 'sveltekit-superforms';

	export let form: SuperForm<Infer<QuizSchema>>;

	const { form: formData } = form;

	const onOutsideClick = () => {
		setTimeout(() => {
			$clickedQuizForm = false;
			$selectedQuizItems = [];
			form.reset();
		}, 100);
	};

	let selectedItems = 0;

	$: if (!$selectQuizItemsForm) selectedItems = $selectedQuizItems.length;

	$: disabled = $formData.name === '';
</script>

{#if $isDesktop}
	<Dialog.Root bind:open={$clickedQuizForm} {onOutsideClick}>
		<Dialog.Overlay class="fixed inset-0 bg-black bg-opacity-30" />
		<Dialog.Content class="z-[100] sm:max-w-[425px]">
			<Dialog.Header>
				<Dialog.Title>Create a quiz</Dialog.Title>
			</Dialog.Header>
			<Form {form}>
				<div slot="custom">
					<Dialog.Root bind:open={$selectQuizItemsForm}>
						<Dialog.Trigger
							class="mb-2 flex w-fit items-center gap-2 rounded-md bg-gray-900 px-3.5 py-2.5 text-sm font-semibold text-white shadow-sm hover:bg-gray-800 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-gray-600"
							on:click={() => ($selectQuizItemsForm = true)}
						>
							<Grid2X2 />
							Quiz Items ({selectedItems})
						</Dialog.Trigger>
						<Dialog.Content class="swap-items z-[101] !h-[40rem] !w-[40rem] p-0">
							<QuizItems flashcardBox={$formData.flashcardBox}>
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
				</div>

				<div slot="add">
					<Button formaction="?/add" class="w-full" {disabled}>Add</Button>
				</div>
			</Form>
		</Dialog.Content>
	</Dialog.Root>
{:else}
	<Drawer.Root onClose={onOutsideClick} open={$clickedQuizForm} {onOutsideClick}>
		<Drawer.Portal>
			<Drawer.Content>
				<Drawer.Header class="text-left">
					<Drawer.Title>Create a quiz</Drawer.Title>
				</Drawer.Header>
				<Form {form}>
					<div slot="custom">
						<Drawer.NestedRoot bind:open={$selectQuizItemsForm}>
							<Drawer.Trigger
								class=" mb-2 flex w-fit items-center gap-2 rounded-md bg-gray-900 px-3.5 py-2.5 text-sm font-semibold text-white shadow-sm hover:bg-gray-800 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-gray-600"
								on:click={() => ($selectQuizItemsForm = true)}
							>
								<Grid2X2 />
								Quiz Items ({selectedItems})
							</Drawer.Trigger>
							<Drawer.Portal>
								<Drawer.Content
									class="select-quiz fixed bottom-0 left-0 right-0 mt-24 flex h-full max-h-[94%] flex-col rounded-t-[10px] bg-gray-100"
								>
									<QuizItems flashcardBox={$formData.flashcardBox}>
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
						</Drawer.NestedRoot>
					</div>

					<div slot="add">
						<Drawer.Close asChild let:builder>
							<Button builders={[builder]} class="w-full" {disabled}>Add</Button>
						</Drawer.Close>
					</div>
				</Form>
				<Drawer.Footer>
					<Drawer.Close asChild let:builder>
						<Button builders={[builder]} variant="outline">Cancel</Button>
					</Drawer.Close>
				</Drawer.Footer>
			</Drawer.Content>
		</Drawer.Portal>
	</Drawer.Root>
{/if}
