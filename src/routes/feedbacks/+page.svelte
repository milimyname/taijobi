<script lang="ts">
	import { goto, invalidateAll } from '$app/navigation';
	import { icons } from '$lib/utils/icons';
	import { clickedReport } from '$lib/utils/stores';
	import { quintOut } from 'svelte/easing';
	import { fly } from 'svelte/transition';
	import { pocketbase } from '$lib/utils/pocketbase.js';

	export let data;

	let formData: {
		name: string;
		description: string;
		device: string;
		image: string;
		user_id: string;
		id: string;
	} = {
		name: '',
		description: '',
		device: '',
		image: '',
		user_id: '',
		id: ''
	};
	let showImage = false;

	const handleSubmit = async () => {
		if (!formData.id) return;

		try {
			await pocketbase.collection('feedbacks').update(formData.id, {
				name: formData.name,
				description: formData.description,
				device: formData.device
			});

			$clickedReport = false;

			invalidateAll();
		} catch (error) {
			console.log(error);
		}
	};
</script>

{#if $clickedReport}
	<div class="fixed top-0 z-[100] h-screen w-full bg-black opacity-50 transition-all" />
{/if}

{#if showImage}
	<div class="fixed top-0 z-[1010] h-screen w-full bg-black opacity-50 transition-all" />
	<img
		src={formData.image}
		alt="Feedback Image"
		class="absolute left-1/2 top-1/2 z-[2000] -translate-x-1/2 -translate-y-1/2"
	/>
	<button
		on:click={() => (showImage = false)}
		class="absolute left-1/2 top-[80%] z-[2010] -translate-x-1/2 -translate-y-1/2 bg-black px-4 py-2 font-bold text-white"
	>
		Close</button
	>
{/if}

{#if $clickedReport}
	<form
		on:submit|preventDefault={handleSubmit}
		class="edit-feedback fixed -bottom-5 z-[1000] flex h-[90%] w-full flex-col gap-5 overflow-hidden rounded-t-2xl bg-white px-5 py-10 sm:bottom-0"
		transition:fly={{
			delay: 0,
			duration: 1000,
			opacity: 0,
			y: 1000,
			easing: quintOut
		}}
	>
		<h4 class="text-2xl">Feedback</h4>

		<div class="mb-auto flex h-full flex-col gap-5">
			<fieldset class=" flex w-full flex-col md:w-2/3">
				<label for="name" class="hidden">Feedback Name</label>
				<input
					type="text"
					name="name"
					placeholder="Feedback Name"
					bind:value={formData.name}
					class="
                    block
                    rounded-md
                    border-gray-300
                    shadow-sm
                    focus:border-indigo-300 focus:ring focus:ring-indigo-200 focus:ring-opacity-50
                  "
				/>
			</fieldset>
			<fieldset class=" flex w-full flex-col md:w-2/3">
				<label for="description" class="hidden">Description</label>
				<textarea
					name="description"
					placeholder="Description"
					bind:value={formData.description}
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
			<fieldset class=" flex w-full flex-col md:w-2/3">
				<label for="model" class="hidden">Device Model</label>
				<input
					type="text"
					name="model"
					bind:value={formData.device}
					placeholder="Device Model"
					class="
                    block
                    rounded-md
                    border-gray-300
                    shadow-sm
                    focus:border-indigo-300 focus:ring focus:ring-indigo-200 focus:ring-opacity-50
                  "
				/>
			</fieldset>
			<div>
				<button type="button" on:click={() => (showImage = true)} class="underline">
					Show Image
				</button>
				<p class="text-sm">Create a new report to change the image</p>
			</div>
		</div>
		<div class="flex justify-between">
			<button
				type="button"
				on:click={async () => {
					if (!formData.id) return;

					try {
						await pocketbase.collection('feedbacks').delete(formData.id);

						$clickedReport = false;

						formData.name = '';
						formData.description = '';
						formData.device = '';
						formData.image = '';
					} catch (error) {
						console.log(error);
					}

					// reload page after 2 seconds
					setTimeout(() => {
						location.reload();
					}, 250);
				}}
				class="rounded-md bg-red-400 px-4 py-2 text-lg font-medium text-white shadow-lg transition duration-200 visited:-translate-x-4 hover:bg-red-500 active:translate-y-1 active:shadow-sm lg:w-2/3"
				>Delete
			</button>
			<div class="flex gap-5">
				<button
					type="button"
					on:click={() => {
						$clickedReport = false;

						formData.name = '';
						formData.description = '';
						formData.device = '';
						formData.id = '';
						formData.image = '';
					}}
					class="rounded-md border px-4 py-2 text-lg font-medium shadow-lg transition duration-200 visited:-translate-x-4 hover:bg-gray-200 active:translate-y-1 active:shadow-sm lg:w-2/3"
					>Cancel
				</button>
				<button
					class="rounded-md bg-black px-4 py-2 text-lg font-medium text-white shadow-lg transition duration-200 visited:-translate-x-4 hover:bg-gray-700 active:translate-y-1 active:shadow-sm lg:w-2/3"
					>Edit Feedback
				</button>
			</div>
		</div>
	</form>
{/if}

<main
	class="flex h-full select-none flex-col items-center gap-10 overflow-hidden bg-white px-3 py-11 transition-all"
>
	<nav class="z-[99] flex w-full justify-between">
		<button on:click|preventDefault={() => goto('/')} class="flex items-center gap-2">
			{@html icons.previous}
			<span>Back</span>
		</button>
	</nav>
	<section class=" flex w-full flex-col gap-2 text-white">
		{#each data.feedbacks as feedback}
			<button
				class="flex w-full flex-col gap-5 rounded-lg bg-black p-4"
				on:click={() => {
					$clickedReport = true;

					formData.name = feedback.name;
					formData.description = feedback.description;
					formData.device = feedback.device;
					formData.id = feedback.id;
					formData.user_id = feedback.user_id;

					formData.image = pocketbase.files.getUrl(feedback, feedback.image);
				}}
			>
				<div class="flex w-full justify-between">
					<h4 class="text-xl font-medium">{feedback.name}</h4>
					<p class="text-sm">{feedback.device}</p>
				</div>
				<p class="line-clamp-3 text-left text-sm">{feedback.description}</p>
			</button>
		{/each}
	</section>
</main>
