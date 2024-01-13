<script lang="ts">
	import { isDesktop } from '$lib/utils';
	import * as Drawer from '$lib/components/ui/drawer';
	import { clickedFeedback } from '$lib/utils/stores';
	import { enhance } from '$app/forms';
</script>

<form
	method="POST"
	use:enhance
	on:submit|preventDefault={() => $isDesktop && ($clickedFeedback = false)}
	enctype="multipart/form-data"
	action="/feedbacks?/create"
	class="feedback-form flex w-full flex-col gap-5 z-100 rounded-t-2xl bg-white
            {!$isDesktop && 'px-4'}"
>
	<div class=" flex flex-col gap-5">
		<fieldset class=" flex w-full flex-col">
			<label for="name">Feedback name</label>
			<input
				type="text"
				name="name"
				class="
									block
									rounded-md
									border-gray-300
									shadow-sm
									focus:border-indigo-300 focus:ring focus:ring-indigo-200 focus:ring-opacity-50
								"
			/>
		</fieldset>
		<fieldset class=" flex w-full flex-col">
			<label for="description">Description</label>
			<textarea
				name="description"
				maxlength="1000"
				class="
									block
									rounded-md
									border-gray-300
									shadow-sm
									focus:border-indigo-300 focus:ring focus:ring-indigo-200 focus:ring-opacity-50
								"
				rows="3"
			/>
		</fieldset>
		<fieldset class=" flex w-full flex-col">
			<label for="model">Device model</label>
			<input
				type="text"
				name="device"
				class="
									block
									rounded-md
									border-gray-300
									shadow-sm
									focus:border-indigo-300 focus:ring focus:ring-indigo-200 focus:ring-opacity-50
								"
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

	{#if $isDesktop}
		<button
			class="w-full mt-auto rounded-md bg-black py-2 text-lg font-medium text-white shadow-lg transition duration-200 visited:-translate-x-4 hover:bg-gray-700 active:translate-y-1 active:shadow-sm"
		>
			Add
		</button>
	{:else}
		<Drawer.Close>
			<button
				class="w-full mt-auto rounded-md bg-black py-2 text-lg font-medium text-white shadow-lg transition duration-200 visited:-translate-x-4 hover:bg-gray-700 active:translate-y-1 active:shadow-sm"
			>
				Add
			</button>
		</Drawer.Close>
	{/if}
</form>
