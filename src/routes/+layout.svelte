<script>
	import { clickedFeedback } from '$lib/utils/stores';
	import { quintOut } from 'svelte/easing';
	import '../app.css';
	import { fly } from 'svelte/transition';
	import { clickOutside } from '$lib/utils/clickOutside';
	import { onMount } from 'svelte';
	import { page } from '$app/stores';
	import { dev } from '$app/environment';

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

		// reload page after 2 seconds
		setTimeout(() => {
			location.reload();
		}, 1000);
	}

	let animationText = '';
	let isReversing = false;

	async function performAnimation() {
		const texts = ['Feedback', 'Bug'];
		const delay = 2000 / (texts[isReversing ? 0 : 1].length - 1);

		for (let i = 0; i < texts[isReversing ? 0 : 1].length; i++) {
			animationText = texts[isReversing ? 0 : 1].slice(0, i + 1);
			await new Promise((resolve) => setTimeout(resolve, delay));
		}

		if (isReversing) {
			isReversing = false;
			performAnimation();
		} else {
			isReversing = true;
			setTimeout(performAnimation, 2000);
		}
	}

	performAnimation();

	/**
	 * @type {HTMLButtonElement}
	 */
	let leaveFeedback;

	$: {
		if (
			$page.url.pathname.slice(1) === 'login' ||
			$page.url.pathname.slice(1) === 'signup' ||
			$page.url.pathname.slice(1) === 'admin'
		) {
			leaveFeedback?.classList.add('hidden');
		} else {
			leaveFeedback?.classList.remove('hidden');
		}
	}
</script>

<svelte:head>
	{#if !dev}
		<script
			async
			src="https://analytics.taijobi.com/script.js"
			data-website-id="51bced60-cf6d-46e0-b27c-0b7dfd457aba"
		></script>
	{/if}
</svelte:head>

{#if $clickedFeedback}
	<div class="fixed top-0 z-[100] h-screen w-full bg-black opacity-50 transition-all" />
{/if}

{#if $clickedFeedback}
	<form
		on:submit|preventDefault={handleSubmit}
		use:clickOutside={() => ($clickedFeedback = false)}
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
	bind:this={leaveFeedback}
	on:click={() => ($clickedFeedback = !$clickedFeedback)}
	class="leave-feedback absolute left-[25%] top-11 z-[888] w-28 -translate-y-1/2 translate-x-1/2 rounded-full border px-4 py-2 sm:left-[40%]"
>
	{animationText}
</button>

<slot />
