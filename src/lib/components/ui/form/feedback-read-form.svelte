<script lang="ts">
	import { cn } from '$lib/utils';
	import * as Form from '$lib/components/ui/form';
	import { type FeedbackSchema } from '$lib/utils/zodSchema';
	import { Button } from '$lib/components/ui/button';
	import { type SuperForm, type Infer } from 'sveltekit-superforms';
	import { Textarea } from '$lib/components/ui/textarea';
	import { getContext } from 'svelte';

	export let disabled = false;

	let form: SuperForm<Infer<FeedbackSchema>> = getContext('feedbackForm');

	const { form: formData, enhance } = form;

	function handleInput(event: Event, field: string) {
		const target = event.target as HTMLInputElement | HTMLTextAreaElement;
		$formData[field] = target.value;
	}

	let showImage = false;
</script>

{#if showImage}
	<img
		src={$formData.image}
		alt="Feedback Preview"
		class="absolute left-1/2 top-1/2 z-[2000] -translate-x-1/2 -translate-y-1/2"
	/>
	<Button
		on:click={() => (showImage = false)}
		class="absolute left-1/2 top-[80%] z-[2010] -translate-x-1/2 -translate-y-1/2 bg-black px-4 py-2 font-bold text-white"
	>
		Close
	</Button>
{/if}

<form
	method="POST"
	action="?/delete"
	use:enhance
	class={cn(
		'edit-form z-[1000] flex size-full flex-col rounded-t-2xl bg-white max-md:px-4',
		!disabled && 'gap-5',
	)}
>
	<div class="mb-auto flex flex-col gap-5">
		<Form.Field {form} name="description">
			<Form.Control let:attrs>
				<Form.Label>Description</Form.Label>
				<Textarea
					data-vaul-no-drag
					class="h-40 resize-y md:h-72"
					{...attrs}
					value={$formData.description}
					on:change={(e) => handleInput(e, 'description')}
					maxlength={1000}
				/>
			</Form.Control>
			<Form.FieldErrors />
		</Form.Field>

		{#if $formData.image !== ''}
			<div>
				<button type="button" on:click={() => (showImage = true)} class="underline">
					Show Image
				</button>
				<p class="text-sm">Create a new report to change the image</p>
			</div>
		{/if}
	</div>
	<div class="flex gap-2">
		<button formaction="?/update" class="grow cursor-not-allowed" {disabled}>
			<slot />
		</button>
	</div>

	<input type="hidden" name="id" value={$formData.id} />
</form>
