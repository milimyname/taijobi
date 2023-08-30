<script>
	import { clickedFeedback } from '$lib/utils/stores';
	import { quintOut } from 'svelte/easing';
	import '../app.css';
	import { fly } from 'svelte/transition';
	import { clickOutside } from '$lib/utils/clickOutside';

	// let audioUrl = '';

	// // Call api youtube-dl
	// onMount(async () => {
	// 	const response = await fetch('/api/youtube-dl', {
	// 		method: 'GET',
	// 		headers: {
	// 			'Content-Type': 'application/json'
	// 		}
	// 	});

	// 	if (!response.ok) throw new Error(response.statusText);

	// 	const { webm } = await response.json();
	// 	audioUrl = webm;
	// 	// const output = await response.json();
	// 	// console.log(output.formats.filter(({ ext }) => ext === 'mp4'));
	// 	// audioUrl = output.formats[34].url;
	// });

	let formData = {
		name: '',
		description: '',
		device: '',
		image: null
	};

	async function handleSubmit() {
		const data = new FormData();
		data.append('name', formData.name);
		data.append('description', formData.description);
		data.append('device', formData.device);
		// @ts-ignore
		data.append('image', formData.image[0]);

		const response = await fetch('/api/feedback', {
			method: 'POST',
			body: data
		});

		if (!response.ok) console.error('Error sending data', await response.text());

		$clickedFeedback = false;
	}
</script>

<!-- {#if audioUrl}
	<audio controls>
		<source src={audioUrl} type="audio/webm" />
		Your browser does not support the audio element.
	</audio>
{/if} -->

{#if $clickedFeedback}
	<div class="fixed top-0 z-[100] h-screen w-full bg-black opacity-50 transition-all" />
{/if}

{#if $clickedFeedback}
	<form
		on:submit|preventDefault={handleSubmit}
		use:clickOutside
		on:outsideclick={() => ($clickedFeedback = false)}
		class="leave-feedback fixed -bottom-5 z-[1000] flex h-[70%] w-full flex-col gap-5 overflow-hidden rounded-t-2xl bg-white px-5 py-10 sm:bottom-0"
		transition:fly={{
			delay: 0,
			duration: 1000,
			opacity: 0,
			y: 1000,
			easing: quintOut
		}}
	>
		<div>
			<h4 class="text-2xl">Leave a feedback or report a bug!</h4>
			<p class="text-sm">
				You can see them here
				<a href="/feedbacks" on:click={() => ($clickedFeedback = false)} class="underline"
					>My Feedbacks</a
				>
			</p>
		</div>
		<div class="mb-auto flex flex-col gap-5">
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
			<input
				type="file"
				bind:files={formData.image}
				class="block w-full cursor-pointer text-sm text-slate-500 transition-all
				file:mr-4 file:rounded-full file:border-0
				file:bg-[#e9f5ff] file:px-4
				file:py-2 file:text-sm
				file:font-semibold file:text-[#40a8f0]
				hover:file:bg-[#bae1ff]"
				accept="image/*"
			/>
		</div>
		<button
			class="w-full rounded-md bg-black py-2 text-lg font-medium text-white shadow-lg transition duration-200 visited:-translate-x-4 hover:bg-gray-700 active:translate-y-1 active:shadow-sm lg:w-2/3"
			>Add
		</button>
	</form>
{/if}

<button
	on:click={() => ($clickedFeedback = !$clickedFeedback)}
	class="leave-feedback absolute left-[45%] top-14 z-[888] -translate-y-1/2 translate-x-1/2"
>
	<svg
		xmlns="http://www.w3.org/2000/svg"
		fill="none"
		viewBox="0 0 24 24"
		stroke-width="1.5"
		stroke="currentColor"
		class="h-6 w-6"
	>
		<path
			stroke-linecap="round"
			stroke-linejoin="round"
			d="M15.182 15.182a4.5 4.5 0 01-6.364 0M21 12a9 9 0 11-18 0 9 9 0 0118 0zM9.75 9.75c0 .414-.168.75-.375.75S9 10.164 9 9.75 9.168 9 9.375 9s.375.336.375.75zm-.375 0h.008v.015h-.008V9.75zm5.625 0c0 .414-.168.75-.375.75s-.375-.336-.375-.75.168-.75.375-.75.375.336.375.75zm-.375 0h.008v.015h-.008V9.75z"
		/>
	</svg>
</button>

<slot />
