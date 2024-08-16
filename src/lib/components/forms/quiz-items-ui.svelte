<script lang="ts">
	import {
		maxFlashcards,
		selectQuizItemsForm,
		selectedQuizItems,
		swapFlashcards,
		startRangeQuizForm,
		endRangeQuizForm,
		flashcardBoxes,
		clickedAddFlahcardBox,
		clickedEditFlashcard,
	} from '$lib/utils/stores';
	import * as Tabs from '$lib/components/ui/tabs';
	import { type QuizSchema } from '$lib/utils/zodSchema';
	import * as Form from '$lib/components/ui/form';
	import { type SuperForm, type Infer } from 'sveltekit-superforms';
	import Input from '$lib/components/ui/input/input.svelte';
	import QuizItems from './quiz-items.svelte';
	import { Button } from '$lib/components/ui/button';
	import * as DrawerDialog from '$lib/components/ui/drawer-dialog';
	import { pocketbase } from '$lib/utils/pocketbase';
	import { invalidateAll } from '$app/navigation';

	export let form: SuperForm<Infer<QuizSchema>>;

	const { form: formData } = form;

	let selectedFlashcardBox: string;

	async function onSwapFlashcards() {
		// Swap the flashcards
		$selectedQuizItems.forEach(async (item) => {
			const [id] = item.split('=');
			await pocketbase.collection('flashcard').update(id, {
				flashcardBox: selectedFlashcardBox,
			});
		});

		// Close the form
		$swapFlashcards = false;
		$selectQuizItemsForm = false;
		$clickedAddFlahcardBox = false;
		$clickedEditFlashcard = false;
		$selectedQuizItems = [];

		invalidateAll();
	}
</script>

<DrawerDialog.Root bind:open={$selectQuizItemsForm}>
	<DrawerDialog.Content className="z-[120] md:max-w-3xl md:p-0">
		<Tabs.Root value="range">
			<Tabs.List class="mx-4 flex flex-1 max-md:mt-10  md:m-5">
				<Tabs.Trigger class="flex-1" value="custom">Custom</Tabs.Trigger>
				<Tabs.Trigger class="flex-1" value="range" disabled={$selectedQuizItems.length !== 0}>
					Range
				</Tabs.Trigger>
			</Tabs.List>
			<Tabs.Content value="custom" class="px-5">
				<QuizItems flashcardBox={$formData.flashcardBox}>
					<div class="relative z-20 space-y-5 p-5 shadow-search-drawer-footer">
						{#if $selectedQuizItems.length < 10 && $selectedQuizItems.length > 0 && !$swapFlashcards}
							<p class="text-center text-sm font-bold text-red-400">
								At least 10 items ({$selectedQuizItems.length})
							</p>
						{/if}
						<div class="flex gap-2">
							<DrawerDialog.Close asChild let:builder>
								<Button
									builders={[builder]}
									on:click={() => {
										$selectQuizItemsForm = false;
										$swapFlashcards = false;
										$selectedQuizItems = [];
									}}
									variant="outline"
									class="w-full"
								>
									Cancel
								</Button>
							</DrawerDialog.Close>

							{#if $swapFlashcards}
								<div class="flex items-center gap-3 sm:gap-5">
									<div>
										<span>Move to</span>
										<select
											bind:value={selectedFlashcardBox}
											class="border-hidden bg-none pr-3 text-center font-bold outline-none focus:border-transparent focus:ring-0"
										>
											{#each $flashcardBoxes as box}
												{#if box.id !== $formData.flashcardBox}
													<option value={box.id}>{box.name}</option>
												{/if}
											{/each}
										</select>
										<span>box</span>
									</div>
									<Button on:click={onSwapFlashcards} class="w-full">Save</Button>
								</div>
							{:else}
								<Button
									disabled={$selectedQuizItems.length < 10}
									on:click={() => {
										$selectQuizItemsForm = false;
										$formData.selectedQuizItems = $selectedQuizItems.join(',');
									}}
									class="w-full"
								>
									{#if $selectedQuizItems.length < 10}
										Not yet
									{:else}
										Save
									{/if}
								</Button>
							{/if}
						</div>
					</div>
				</QuizItems>
			</Tabs.Content>

			<Tabs.Content value="range" class="h-[32rem] px-4">
				<div class="flex h-full flex-col justify-between">
					<div class="grid grid-cols-2 gap-2">
						<Form.Field {form} name="startCount">
							<Form.Control let:attrs>
								<Form.Label>Start</Form.Label>
								<Input
									{...attrs}
									type="number"
									min={1}
									max={+$maxFlashcards - 10}
									bind:value={$startRangeQuizForm}
								/>
							</Form.Control>
							<Form.FieldErrors />
						</Form.Field>

						<Form.Field {form} name="maxCount">
							<Form.Control let:attrs>
								<Form.Label>End ({$maxFlashcards})</Form.Label>
								<Input
									{...attrs}
									type="number"
									min={10}
									max={$maxFlashcards}
									bind:value={$endRangeQuizForm}
								/>
							</Form.Control>
							<Form.FieldErrors />
						</Form.Field>
					</div>

					<div class="flex flex-col gap-2 pb-5">
						<DrawerDialog.Close asChild let:builder>
							<Button
								builders={[builder]}
								on:click={() => ($selectQuizItemsForm = false)}
								class="w-full"
							>
								Save
							</Button>
						</DrawerDialog.Close>

						<DrawerDialog.Footer className="md:hidden p-0">
							<DrawerDialog.Close asChild let:builder>
								<Button
									builders={[builder]}
									on:click={() => {
										setTimeout(() => {
											$selectQuizItemsForm = false;
											$selectedQuizItems = [];
										}, 100);
									}}
									class="w-full"
									variant="outline"
								>
									Cancel
								</Button>
							</DrawerDialog.Close>
						</DrawerDialog.Footer>
					</div>
				</div>
			</Tabs.Content>
		</Tabs.Root>
	</DrawerDialog.Content>
</DrawerDialog.Root>
