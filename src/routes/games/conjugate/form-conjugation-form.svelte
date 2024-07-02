<script lang="ts">
	import { type ConjugationFormSchema } from '$lib/utils/zodSchema';
	import type { SuperForm, Infer } from 'sveltekit-superforms';
	import * as Form from '$lib/components/ui/form';
	import { Input } from '$lib/components/ui/input';
	import { getContext } from 'svelte';
	import { page } from '$app/stores';
	import { VERB_CONJUGATION_TYPES } from '$lib/utils/constants';
	import Checkbox from '$lib/components/ui/checkbox/checkbox.svelte';
	import Label from '$lib/components/ui/label/label.svelte';

	let form: SuperForm<Infer<ConjugationFormSchema>> = getContext('superConjugationForm');

	const { form: formData, enhance } = form;
</script>

<form method="POST" use:enhance class="search-form z-[1000] flex w-full flex-col px-5 space-y-5">
	<div class="mb-auto flex flex-col gap-2">
		<Form.Field {form} name="name">
			<Form.Control let:attrs>
				<Form.Label>Conjugation Quiz Name</Form.Label>
				<Input {...attrs} bind:value={$formData.name} />
			</Form.Control>
			<Form.FieldErrors />
		</Form.Field>

		<div class="space-y-2">
			<Label>Settings</Label>
			<Form.Field
				{form}
				name="settings"
				class="grid items-center gap-4 grid-cols-[repeat(2,1rem_1fr)] space-y-0 px-5 md:px-0"
			>
				<Form.Control let:attrs>
					{#each Object.entries(VERB_CONJUGATION_TYPES) as [type, value]}
						<Checkbox
							{...attrs}
							checked={$formData.settings.includes(value)}
							on:click={() => {
								if ($formData.settings.includes(value))
									$formData.settings = $formData.settings.filter((item) => item !== value);
								else $formData.settings = [...$formData.settings, value];

								// localStorage.setItem(
								// 	`conjugationSettings_${selectedConjugation?.id}`,
								// 	JSON.stringify(checkedList),
								// );
							}}
						/>
						<Form.Label for={type}>{value}</Form.Label>
					{/each}
				</Form.Control>
			</Form.Field>
		</div>
		<!-- Pass data to server -->
		<input type="hidden" name="flashcards" value={$formData.flashcards} />
	</div>

	<button formaction="?/add" class="cursor-not-allowed">
		<slot name="add" />
	</button>
</form>
