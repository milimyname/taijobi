<script lang="ts">
	import { cn, isDesktop } from '$lib/utils';
	import { clickedFeedback, feedbackDescription } from '$lib/utils/stores';
	import { enhance } from '$app/forms';
	import { Label } from '$lib/components/ui/label';
	import { Textarea } from '$lib/components/ui/textarea';
	import { toast } from 'svelte-sonner';
	import { goto } from '$app/navigation';

	function onSubmit() {
		$clickedFeedback = false;
		$feedbackDescription = '';

		toast('Feedback submitted!', {
			action: {
				label: 'See it now',
				onClick: () => {
					goto('/feedbacks');
				},
			},
		});
	}

	export let disabled = false;
</script>

<form
	method="POST"
	use:enhance
	on:submit={onSubmit}
	enctype="multipart/form-data"
	action="/feedbacks?/create"
	class={cn(
		'feedback-form z-100 flex size-full flex-col gap-5 rounded-t-2xl bg-white',
		!$isDesktop && 'px-4',
	)}
>
	<div class="mb-auto flex flex-col gap-5">
		<fieldset class="flex w-full flex-col gap-2">
			<Label for="description">Description</Label>
			<Textarea
				data-vaul-no-drag
				class="resize-y"
				name="description"
				maxlength={1000}
				required
				bind:value={$feedbackDescription}
			/>
		</fieldset>
		<input
			type="file"
			name="image"
			class="block w-full cursor-pointer text-sm text-slate-500 transition-all
									file:mr-4 file:rounded-full file:border-0
									file:bg-[#e9f5ff] file:px-4
									file:py-2 file:text-sm
									file:font-semibold file:text-[#40a8f0]
									hover:file:bg-[#bae1ff]"
			accept="image/*"
		/>
	</div>

	<button {disabled}>
		<slot />
	</button>
</form>
