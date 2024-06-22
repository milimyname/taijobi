<script lang="ts">
	import { type SearchCollectionSchema } from '$lib/utils/zodSchema';
	import type { SuperForm, Infer } from 'sveltekit-superforms';
	import * as Form from '$lib/components/ui/form';
	import { Input } from '$lib/components/ui/input';
	import { cn, isDesktop } from '$lib/utils';
	import { getContext } from 'svelte';
	import * as Select from '$lib/components/ui/select';

	type FlashcardCollection = {
		id: string;
		name: string;
		boxes: { id: string; name: string }[];
	};

	let form: SuperForm<Infer<SearchCollectionSchema>> = getContext('flashcardCollectionForm');

	const collections: FlashcardCollection[] = getContext('flashcardCollections');

	const { form: formData, enhance } = form;

	$: selectedCollection = $formData.collectionId
		? {
				value: $formData.collectionId,
				label: collections?.find((c) => c.id === $formData.collectionId)?.name || 'New Collection',
				boxes: collections?.find((c) => c.id === $formData.collectionId)?.boxes || [],
			}
		: undefined;

	$: selectedBox = $formData.boxId
		? {
				value: $formData.boxId,
				label: selectedCollection?.boxes.find((b) => b.id === $formData.boxId)?.name || 'New Box',
			}
		: undefined;

	$: if ($formData.collectionId === 'new-collection') $formData.boxId = 'new-box';
</script>

<form
	method="POST"
	use:enhance
	class={cn('search-form z-[1000] flex w-full flex-col', !$isDesktop && 'px-4')}
>
	<div class="mb-auto flex flex-col gap-2">
		<Form.Field {form} name="collectionId">
			<Form.Control let:attrs>
				<Form.Label>Collection</Form.Label>
				<Select.Root
					selected={selectedCollection}
					onSelectedChange={(v) => v && ($formData.collectionId = v.value)}
				>
					<Select.Trigger {...attrs}>
						<Select.Value placeholder="Select a collection" />
					</Select.Trigger>
					<Select.Content>
						{#each collections as collection}
							<Select.Item value={collection.id} label={collection.name} />
						{/each}
						<Select.Item value="new-collection" label="New Collection" />
					</Select.Content>
				</Select.Root>
			</Form.Control>
			<Form.FieldErrors />
		</Form.Field>
		{#if selectedCollection?.label === 'New Collection'}
			<Form.Field {form} name="collectionName">
				<Form.Control let:attrs>
					<Form.Label>New Collection Name</Form.Label>
					<Input {...attrs} bind:value={$formData.collectionName} />
				</Form.Control>
				<Form.FieldErrors />
			</Form.Field>
		{/if}

		{#if selectedCollection?.label !== 'New Collection'}
			<Form.Field {form} name="boxId">
				<Form.Control let:attrs>
					<Form.Label>Flashcard Boxes</Form.Label>
					<Select.Root
						selected={selectedBox}
						onSelectedChange={(v) => v && ($formData.boxId = v.value)}
						disabled={!selectedCollection}
					>
						<Select.Trigger {...attrs}>
							<Select.Value placeholder="Select a box" />
						</Select.Trigger>
						<Select.Content>
							{#each selectedCollection?.boxes as box}
								<Select.Item value={box.id} label={box.name} />
							{/each}
							<Select.Item value="new-box" label="New Box" />
						</Select.Content>
					</Select.Root>
				</Form.Control>
				<Form.FieldErrors />
			</Form.Field>
		{/if}

		{#if selectedBox?.label === 'New Box' || selectedCollection?.label === 'New Collection'}
			<Form.Field {form} name="boxName">
				<Form.Control let:attrs>
					<Form.Label>New Box Name</Form.Label>
					<Input {...attrs} bind:value={$formData.boxName} />
				</Form.Control>
				<Form.FieldErrors />
			</Form.Field>
		{/if}

		<!-- Pass data to server -->
		<input type="hidden" name="boxName" value={$formData.boxName} />
		<input type="hidden" name="collectionName" value={$formData.collectionName} />
		<input type="hidden" name="collectionId" value={$formData.collectionId} />
		<input type="hidden" name="boxId" value={$formData.boxId} />
		<input type="hidden" name="flashcardBoxes" value={$formData.flashcards} />
	</div>

	<button formaction="?/add" class="cursor-not-allowed">
		<slot name="add" />
	</button>
</form>
