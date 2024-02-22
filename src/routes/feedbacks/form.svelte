<script lang="ts">
	import { isDesktop } from '$lib/utils';
	import * as Form from '$lib/components/ui/form';
	import { feedbackSchema, type FeedbackSchema } from '$lib/utils/zodSchema';
	import { Button } from '$lib/components/ui/button';
	import { type SuperForm } from 'sveltekit-superforms/client';

	export let form: SuperForm<FeedbackSchema>;

	let formData = form.form;

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

<Form.Root
	method="POST"
	{form}
	controlled
	schema={feedbackSchema}
	action="?/update"
	let:config
	class="edit-form z-[1000] flex w-full flex-col gap-5 rounded-t-2xl bg-white
           			 {!$isDesktop && 'px-4'}"
>
	<div class=" flex flex-col gap-5">
		<Form.Field {config} name="name">
			<Form.Item>
				<Form.Label>Name</Form.Label>
				<Form.Input />
				<Form.Validation />
			</Form.Item>
		</Form.Field>

		<Form.Field {config} name="description">
			<Form.Item>
				<Form.Label>Description</Form.Label>
				<Form.Textarea maxlength={1000} rows={3} />
				<Form.Validation />
			</Form.Item>
		</Form.Field>

		<Form.Field {config} name="device">
			<Form.Item>
				<Form.Label>Device Model</Form.Label>
				<Form.Input />
				<Form.Validation />
			</Form.Item>
		</Form.Field>

		{#if $formData.image !== ''}
			<div>
				<button type="button" on:click={() => (showImage = true)} class="underline">
					Show Image
				</button>
				<p class="text-sm">Create a new report to change the image</p>
			</div>
		{/if}

		<Form.Field {config} name="id">
			<Form.Item>
				<Form.Input type="hidden" />
			</Form.Item>
		</Form.Field>

		<div class="flex w-full {!$isDesktop && 'flex-col gap-2'} justify-between">
			<Form.Button variant="destructive" formaction="?/delete">Delete</Form.Button>
			<Form.Button formaction="?/update">Update</Form.Button>
		</div>
	</div>
</Form.Root>
