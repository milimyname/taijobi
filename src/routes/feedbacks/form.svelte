<script lang="ts">
	// Will be refactored later
	import { isDesktop } from '$lib/utils';
	import { slide } from 'svelte/transition';
	import { quintOut } from 'svelte/easing';
	import * as Drawer from '$lib/components/ui/drawer';

	export let showImage: boolean;
	export let form: any;
	export let errors: any;
	export let constraints: any;
	export let enhance: any;
</script>

<form
	method="POST"
	use:enhance
	action="?/update"
	class="edit-form flex w-full flex-col gap-5 z-[1000] rounded-t-2xl bg-white
           			 {!$isDesktop && 'px-4'}"
>
	<input type="text" name="id" bind:value={$form.id} class="hidden" />
	<div class="mb-auto flex h-full flex-col gap-5">
		<fieldset class=" flex w-full flex-col">
			<label for="name">Name</label>
			<input
				type="text"
				name="name"
				bind:value={$form.name}
				class="
								block
								rounded-md
								border-gray-300
								shadow-sm
								focus:border-indigo-300 focus:ring focus:ring-indigo-200 focus:ring-opacity-50
							"
				{...$constraints.name}
			/>
			{#if $errors.name}
				<span
					transition:slide={{ delay: 0, duration: 300, easing: quintOut, axis: 'y' }}
					class="mt-1 select-none text-sm text-red-400">{$errors.name}</span
				>
			{/if}
		</fieldset>
		<fieldset class=" flex w-full flex-col">
			<label for="description">Description</label>
			<textarea
				name="description"
				bind:value={$form.description}
				maxlength="1000"
				class="block
									rounded-md
									border-gray-300
									shadow-sm
									focus:border-indigo-300 focus:ring focus:ring-indigo-200 focus:ring-opacity-50
								"
				rows="3"
				{...$constraints.description}
			/>
			{#if $errors.description}
				<span
					transition:slide={{ delay: 0, duration: 300, easing: quintOut, axis: 'y' }}
					class="mt-1 select-none text-sm text-red-400"
				>
					{$errors.description}
				</span>
			{/if}
		</fieldset>
		<fieldset class=" flex w-full flex-col">
			<label for="model">Device model</label>
			<input
				type="text"
				name="model"
				bind:value={$form.device}
				class="block
									rounded-md
									border-gray-300
									shadow-sm
									focus:border-indigo-300 focus:ring focus:ring-indigo-200 focus:ring-opacity-50
								"
				{...$constraints.device}
			/>
			{#if $errors.device}
				<span
					transition:slide={{ delay: 0, duration: 300, easing: quintOut, axis: 'y' }}
					class="mt-1 select-none text-sm text-red-400"
				>
					{$errors.device}
				</span>
			{/if}
		</fieldset>
		<div>
			<button type="button" on:click={() => (showImage = true)} class="underline">
				Show Image
			</button>
			<p class="text-sm">Create a new report to change the image</p>
		</div>
	</div>
	<div class="flex justify-between flex-col gap-2">
		{#if $isDesktop}
			<button
				formaction="?/delete"
				class="rounded-md bg-red-400 px-4 py-2 text-lg font-medium text-white shadow-lg transition duration-200 visited:-translate-x-4 hover:bg-red-500 active:translate-y-1 active:shadow-sm"
			>
				Delete
			</button>
			<button
				class="rounded-md bg-black px-4 py-2 text-lg font-medium text-white shadow-lg transition duration-200 visited:-translate-x-4 hover:bg-gray-700 active:translate-y-1 active:shadow-sm"
			>
				Update
			</button>
		{:else}
			<Drawer.Close>
				<button
					class="rounded-md w-full bg-black px-4 py-2 text-lg font-medium text-white shadow-lg transition duration-200 visited:-translate-x-4 hover:bg-gray-700 active:translate-y-1 active:shadow-sm"
				>
					Update
				</button>
			</Drawer.Close>

			<Drawer.Close>
				<button
					formaction="?/delete"
					class="rounded-md w-full bg-red-400 px-4 py-2 text-lg font-medium text-white shadow-lg transition duration-200 visited:-translate-x-4 hover:bg-red-500 active:translate-y-1 active:shadow-sm"
				>
					Delete
				</button>
			</Drawer.Close>
		{/if}
	</div>
</form>
