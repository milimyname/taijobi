<script lang="ts">
	import { browser } from '$app/environment';
	import { goto, invalidateAll } from '$app/navigation';
	import { pocketbase } from '$lib/utils/pocketbase';
	import { Badge } from '$lib/components/ui/badge/index';
	import Onyomi from '$lib/icons/Onyomi.svelte';
	import Kunyomi from '$lib/icons/Kunyomi.svelte';
	import { Captions, Earth, ArrowDownUp } from 'lucide-svelte';
	import { type ComponentType, tick } from 'svelte';
	import { cn } from '$lib/utils.js';
	import * as Popover from '$lib/components/ui/popover/index.js';
	import * as Command from '$lib/components/ui/command/index.js';
	import { Button } from '$lib/components/ui/button/index';
	import type { RecordModel } from 'pocketbase';

	export let data;

	let open = false;
	let value = '';
	let sortedByDate = false;
	let hiddenExamples = false;

	type Type = {
		value: string;
		label: string;
		icon: ComponentType;
	};

	const types: Type[] = [
		{
			value: 'name',
			label: 'Name',
			icon: Captions
		},
		{
			value: 'meaning',
			label: 'Meaning',
			icon: Earth
		},
		{
			value: 'onyomi',
			label: 'Onyomi',
			icon: Onyomi
		},
		{
			value: 'kunyomi',
			label: 'Kunyomi',
			icon: Kunyomi
		}
	];

	$: quizzes = data.quizzes;

	$: selectedType = types.find((t) => t.value === value) ?? null;

	$: if (selectedType)
		quizzes = data.quizzes.filter((quiz: RecordModel) => quiz.type === selectedType.value);

	$: if (sortedByDate)
		quizzes = quizzes.sort(
			(a: RecordModel, b: RecordModel) => new Date(b.created) - new Date(a.created)
		);
	else
		quizzes = quizzes.sort(
			(a: RecordModel, b: RecordModel) => new Date(a.created) - new Date(b.created)
		);

	$: if (hiddenExamples) {
		quizzes = quizzes.filter(
			(quiz: RecordModel) => quiz.id !== 'hiragana' && quiz.id !== 'katakana'
		);
	}

	// We want to refocus the trigger button when the user selects
	// an item from the list so users can continue navigating the
	// rest of the form with the keyboard.
	function closeAndFocusTrigger(triggerId: string) {
		open = false;
		tick().then(() => {
			document.getElementById(triggerId)?.focus();
		});
	}
</script>

<section class="flex w-full max-w-4xl flex-col justify-center gap-5 overflow-y-scroll">
	<div class="flex flex-wrap gap-2">
		<Button size="sm" variant="outline" on:click={() => (hiddenExamples = !hiddenExamples)}>
			<span> Hide Examples </span>
		</Button>
		<Button size="sm" variant="outline" on:click={() => (sortedByDate = !sortedByDate)}>
			<ArrowDownUp class="mr-2 size-4" />
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
													'fill-foreground/40'
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
	<div class="grid grid-flow-row gap-4 md:grid-cols-3">
		{#each quizzes as quiz}
			{@const anyProgress = browser && localStorage.getItem(`quizProgress_${quiz.id}`)}
			<a
				class="flex w-full flex-col justify-center gap-4 rounded-lg border p-4"
				href={`/games/quizzes/${quiz.id}`}
			>
				<div class="space-y-2">
					<div class="flex justify-between">
						<h4 class="text-xl font-medium">Quiz: {quiz.name}</h4>

						<Badge variant="outline">
							{quiz.type}
						</Badge>
					</div>

					<span class="line-clamp-3 text-left text-sm">Amount: {quiz.maxCount}</span>
				</div>

				<div class="flex justify-between">
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

					{#if quiz.id !== 'hiragana' && quiz.id !== 'katakana'}
						<button
							class="self-center rounded-full font-bold text-red-600"
							on:click|preventDefault={async () => {
								localStorage.removeItem(`flashcards_${quiz.id}`);
								localStorage.removeItem(`currentQuestion_${quiz.id}`);
								localStorage.removeItem(`quizProgress_${quiz.id}`);

								await pocketbase.collection('quizzes').delete(quiz.id);

								invalidateAll();
							}}
						>
							Delete
						</button>
					{/if}
				</div>
			</a>
		{/each}
	</div>
</section>
