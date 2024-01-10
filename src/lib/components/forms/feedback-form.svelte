<script>
	import { clickedFeedback } from '$lib/utils/stores';
	import { isDesktop } from '$lib/utils';

	let formData = {
		name: '',
		description: '',
		device: '',
		image: null
	};

	async function handleSubmit() {
		$clickedFeedback = false;
		const data = new FormData();
		data.append('name', formData.name);
		data.append('description', formData.description);
		data.append('device', formData.device);
		if (formData.image) data.append('image', formData.image[0]);

		const response = await fetch('/api/feedback', {
			method: 'POST',
			body: data
		});

		if (!response.ok) {
			console.error('Error sending data', await response.text());
			return;
		}

		formData = {
			name: '',
			description: '',
			device: '',
			image: null
		};
	}
</script>

<form
	on:submit|preventDefault={handleSubmit}
	class="feedback-form flex w-full flex-col gap-5 z-100 rounded-t-2xl bg-white
            {!$isDesktop && 'px-4'}"
>
	<div class=" flex flex-col gap-5">
		<fieldset class=" flex w-full flex-col">
			<label for="name">Feedback name</label>
			<input
				type="text"
				name="name"
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
		<fieldset class=" flex w-full flex-col">
			<label for="description">Description</label>
			<textarea
				name="description"
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
		<fieldset class=" flex w-full flex-col">
			<label for="model">Device model</label>
			<input
				type="text"
				name="model"
				bind:value={formData.device}
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
		class="w-full mt-auto rounded-md bg-black py-2 text-lg font-medium text-white shadow-lg transition duration-200 visited:-translate-x-4 hover:bg-gray-700 active:translate-y-1 active:shadow-sm"
	>
		Add
	</button>
</form>
