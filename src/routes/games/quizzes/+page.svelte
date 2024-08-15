<script lang="ts">
	import { browser } from '$app/environment';
	import { goto } from '$app/navigation';
	import { pocketbase } from '$lib/utils/pocketbase';
	import { Badge } from '$lib/components/ui/badge/index';
	import Onyomi from '$lib/icons/Onyomi.svelte';
	import Kunyomi from '$lib/icons/Kunyomi.svelte';
	import { Captions, Earth, ArrowDown10, ArrowDown01, Trash2 } from 'lucide-svelte';
	import { type ComponentType, tick } from 'svelte';
	import { cn } from '$lib/utils.js';
	import * as Popover from '$lib/components/ui/popover/index.js';
	import * as Command from '$lib/components/ui/command/index.js';
	import { Button } from '$lib/components/ui/button/index';
	import type { RecordModel } from 'pocketbase';
	import { ScrollArea } from '$lib/components/ui/scroll-area/index';
	import * as Tooltip from '$lib/components/ui/tooltip';
	import DeleteTrashButton from '$lib/components/delete-trash-button.svelte';
	import DeleteDrawerAlertDialog from '$lib/components/drawer-alert-dialogs/delete-drawer-alert-dialog.svelte';
	import { toast } from 'svelte-sonner';
	import { deleteDrawerDialogOpen } from '$lib/utils/stores';

	export let data;

	let open = false;
	let value = '';
	let sortedByDate = false;
	let hiddenExamples = false;
	let loading = false;

	type Type = {
		value: string;
		label: string;
		icon: ComponentType;
	};

	const types: Type[] = [
		{
			value: 'name',
			label: 'Name',
			icon: Captions,
		},
		{
			value: 'meaning',
			label: 'Meaning',
			icon: Earth,
		},
		{
			value: 'onyomi',
			label: 'Onyomi',
			icon: Onyomi,
		},
		{
			value: 'kunyomi',
			label: 'Kunyomi',
			icon: Kunyomi,
		},
	];

	let quizzes: RecordModel[] = data.quizzes;
	let currentQuiz: RecordModel;

	$: selectedType = types.find((t) => t.value === value) ?? null;

	$: quizzes = (() => {
		// First, filter by selectedType if any, then apply hiddenExamples filter
		let filteredQuizzes = data.quizzes
			.filter((quiz: RecordModel) => !selectedType || quiz.type === selectedType.value)
			.filter(
				(quiz: RecordModel) =>
					!hiddenExamples || (quiz.id !== 'hiragana' && quiz.id !== 'katakana'),
			);

		// Then, sort the filtered quizzes based on sortedByDate
		return sortedByDate
			? filteredQuizzes.sort(
					(a: RecordModel, b: RecordModel) =>
						Number(new Date(b.created)) - Number(new Date(a.created)),
				)
			: filteredQuizzes.sort(
					(a: RecordModel, b: RecordModel) =>
						Number(new Date(a.created)) - Number(new Date(b.created)),
				);
	})();

	// We want to refocus the trigger button when the user selects
	// an item from the list so users can continue navigating the
	// rest of the form with the keyboard.
	function closeAndFocusTrigger(triggerId: string) {
		open = false;
		tick().then(() => {
			document.getElementById(triggerId)?.focus();
		});
	}

	async function deleteQuiz() {
		loading = true;
		try {
			// Update quiz count in flashcardBox
			const flashcardBox = await pocketbase
				.collection('flashcardBoxes')
				.getOne(currentQuiz.flashcardBox);

			await pocketbase.collection('flashcardBoxes').update(flashcardBox.id, {
				quizCount: flashcardBox.quizCount - 1,
			});
		} catch (error) {
			console.error(error);
		}

		try {
			localStorage.removeItem(`flashcards_${currentQuiz.id}`);
			localStorage.removeItem(`currentQuestion_${currentQuiz.id}`);
			localStorage.removeItem(`quizProgress_${currentQuiz.id}`);

			await pocketbase.collection('quizzes').delete(currentQuiz.id);
		} catch (error) {
			console.error(error);
		}

		// Remove from the list
		quizzes = quizzes.filter((q) => q.id !== currentQuiz.id);

		// $openHistory = false;
		loading = false;

		setTimeout(() => ($deleteDrawerDialogOpen = false), 150);

		toast.success('Search history deleted successfully.');
	}
</script>

<DeleteDrawerAlertDialog onClick={deleteQuiz} />

<section class="flex w-full max-w-4xl flex-col justify-center gap-5 max-lg:px-2">
	<div class="sticky top-0 z-50 flex flex-wrap gap-2 bg-white max-md:py-2">
		<Button size="sm" variant="outline" on:click={() => (hiddenExamples = !hiddenExamples)}>
			{#if hiddenExamples}
				<span>Show examples</span>
			{:else}
				<span>Hide examples</span>
			{/if}
		</Button>
		<Button size="sm" variant="outline" on:click={() => (sortedByDate = !sortedByDate)}>
			{#if sortedByDate}
				<ArrowDown10 class="mr-2 size-5" />
			{:else}
				<ArrowDown01 class="mr-2 size-5" />
			{/if}
			<span>Sorted by date</span>
		</Button>
		<div class="flex items-center space-x-4">
			<Popover.Root bind:open let:ids>
				<Popover.Trigger asChild let:builder>
					<Button builders={[builder]} variant="outline" size="sm" class="w-[150px] justify-start">
						{#if selectedType}
							<svelte:component this={selectedType.icon} class="mr-2 size-4 shrink-0" />
							{selectedType.label}
						{:else}
							+ Set type
						{/if}
					</Button>
				</Popover.Trigger>
				<Popover.Content class="w-[200px] p-0" side="right" align="start">
					<Command.Root>
						<Command.Input placeholder="Change type..." />
						<Command.List>
							<Command.Empty>No results found.</Command.Empty>
							<Command.Group>
								{#each types as type}
									<Command.Item
										value={type.value}
										onSelect={(currentValue) => {
											// if the user selects the same value, clear it and show all items
											if (currentValue === value) {
												value = '';
												closeAndFocusTrigger(ids.trigger);
												quizzes = data.quizzes;
												return;
											}

											value = currentValue;
											closeAndFocusTrigger(ids.trigger);
										}}
									>
										<svelte:component
											this={type.icon}
											class={cn(
												'mr-2 size-4',
												type.value !== selectedType?.value && 'text-foreground/40',
												type.value !== selectedType?.value &&
													(type.value === 'onyomi' || type.value === 'kunyomi') &&
													'fill-foreground/40',
											)}
										/>

										<span>
											{type.label}
										</span>
									</Command.Item>
								{/each}
							</Command.Group>
						</Command.List>
					</Command.Root>
				</Popover.Content>
			</Popover.Root>
		</div>
	</div>
	<div class="grid grid-flow-row gap-4 max-md:pb-5 md:grid-cols-3">
		{#each quizzes as quiz}
			{@const anyProgress = browser && localStorage.getItem(`quizProgress_${quiz.id}`)}
			<a
				class="flex w-full flex-col justify-center gap-4 rounded-lg border p-4"
				href={`/games/quizzes/${quiz.id}`}
			>
				<div class="space-y-2">
					<div class="flex items-start justify-between gap-2">
						<Tooltip.Root>
							<ScrollArea class="max-w-fit" orientation="horizontal">
								<Tooltip.Trigger>
									<h4 class="text-left text-xl font-medium sm:truncate">Quiz: {quiz.name}</h4>
								</Tooltip.Trigger>
							</ScrollArea>
							<Tooltip.Content>
								<p>{quiz.name}</p>
							</Tooltip.Content>
						</Tooltip.Root>

						{#if quiz.id !== 'hiragana' && quiz.id !== 'katakana'}
							<DeleteTrashButton
								{loading}
								className="my-auto"
								onClick={(e) => {
									e.preventDefault();
									currentQuiz = quiz;
									$deleteDrawerDialogOpen = true;
								}}
							/>
						{/if}
					</div>

					<div class="flex gap-2">
						<Badge variant="outline">
							{quiz.type}
						</Badge>

						<Badge variant="outline">
							{quiz.maxCount}
						</Badge>
					</div>
				</div>

				<div class="flex flex-wrap justify-between gap-2">
					<button
						class="self-center rounded-full font-bold"
						on:click={() => {
							localStorage.removeItem(`flashcards_${quiz.id}`);
							localStorage.removeItem(`currentQuestion_${quiz.id}`);
							localStorage.removeItem(`quizProgress_${quiz.id}`);
							goto(`/games/quizzes/${quiz.id}`);
						}}
					>
						Restart
					</button>
					{#if anyProgress}
						<button
							class="self-center rounded-full font-bold"
							on:click={() => goto(`/games/quizzes/${quiz.id}`)}
						>
							Continue from {JSON.parse(anyProgress).length}
						</button>
					{/if}
				</div>
			</a>
		{/each}
	</div>
</section>
