<script lang="ts">
	import { cn, isDesktop } from '$lib/utils';
	import * as Form from '$lib/components/ui/form';
	import { type FeedbackSchema } from '$lib/utils/zodSchema';
	import { Button } from '$lib/components/ui/button';
	import { type SuperForm, type Infer } from 'sveltekit-superforms';
	import { Textarea } from '$lib/components/ui/textarea';
	import { Input } from '$lib/components/ui/input';

	export let form: SuperForm<Infer<FeedbackSchema>>;

	const { form: formData, enhance } = form;

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
	action="?/update"
	use:enhance
	class={cn(
		'edit-form z-[1000] flex w-full flex-col gap-5 rounded-t-2xl bg-white',
		!$isDesktop && 'px-4'
	)}
>
	<div class="flex flex-col gap-5">
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

		<Form.Field {form} name="device">
			<Form.Control let:attrs>
				<Form.Label>Device Model</Form.Label>
				<Input {...attrs} bind:value={$formData.device} />
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

		<input type="hidden" name="id" bind:value={$formData.id} />

		<div class="flex w-full {!$isDesktop && 'flex-col gap-2'} justify-between">
			<Form.Button variant="destructive" formaction="?/delete">Delete</Form.Button>
			<Form.Button formaction="?/update">Update</Form.Button>
		</div>
	</div>
</form>
