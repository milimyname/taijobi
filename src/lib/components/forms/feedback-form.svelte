<script lang="ts">
	import { isDesktop } from '$lib/utils';
	import { clickedFeedback } from '$lib/utils/stores';
	import { enhance } from '$app/forms';
	import { Label } from '$lib/components/ui/label';
	import { Textarea } from '$lib/components/ui/textarea';
</script>

<form
	method="POST"
	use:enhance
	on:submit={() => ($clickedFeedback = false)}
	enctype="multipart/form-data"
	action="/feedbacks?/create"
	class="feedback-form z-100 flex w-full flex-col gap-5 rounded-t-2xl bg-white
            {!$isDesktop && 'px-4'}"
>
	<div class="flex flex-col gap-5">
		<fieldset class=" flex w-full flex-col gap-2">
			<Label for="description">Description</Label>
			<Textarea name="description" maxlength={1000} rows={3} required />
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

	<button>
		<slot />
	</button>
</form>
