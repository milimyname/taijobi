<script lang="ts">
	import { superForm } from 'sveltekit-superforms/client';
	import { slide } from 'svelte/transition';
	import { quintOut } from 'svelte/easing';

	export let data;
	const { form, errors, constraints, enhance } = superForm(data.form, {
		taintedMessage: null
	});

	$: {
		$form.email = data.user.email;
		$form.username = data.user.username;
	}
</script>

<section class="mb-auto w-full rounded-t-4xl border border-[#EEEEEE] px-10 py-10 sm:w-1/2 sm:px-16">
	<form action="?/changeProfileData" class="flex flex-col gap-8" method="POST" use:enhance>
		<div class="flex justify-between">
			<h4 class="text-3xl font-bold">Profile Data</h4>
			<button>Save</button>
		</div>
		<div class="flex flex-col gap-4">
			<fieldset class="flex w-full flex-col md:w-2/3">
				<label for="username" class="hidden">Username</label>
				<input
					type="text"
					name="username"
					placeholder="username"
					class="
                    block
                    rounded-md
                    border-gray-300
                    shadow-sm
                    focus:border-indigo-300 focus:ring focus:ring-indigo-200 focus:ring-opacity-50
                  "
					aria-invalid={$errors.username ? 'true' : undefined}
					bind:value={$form.username}
					{...$constraints.username}
				/>
				{#if $errors.username}<span
						transition:slide={{ delay: 0, duration: 300, easing: quintOut, axis: 'y' }}
						class="mt-1 select-none text-sm text-red-400">{$errors.username}</span
					>{/if}
			</fieldset>
			<fieldset class="flex w-full flex-col md:w-2/3">
				<label for="email" class="hidden">Email</label>
				<input
					type="text"
					name="email"
					placeholder="email"
					class="
                    block
                    rounded-md
                    border-gray-300
                    shadow-sm
                    focus:border-indigo-300 focus:ring focus:ring-indigo-200 focus:ring-opacity-50
                  "
					aria-invalid={$errors.email ? 'true' : undefined}
					bind:value={$form.email}
					{...$constraints.email}
				/>
				{#if $errors.email}<span
						transition:slide={{ delay: 0, duration: 300, easing: quintOut, axis: 'y' }}
						class="mt-1 select-none text-sm text-red-400">{$errors.email}</span
					>{/if}
			</fieldset>
			<input
				type="file"
				class="block w-full cursor-pointer text-sm text-slate-500 transition-all
				file:mr-4 file:rounded-full file:border-0
				file:bg-[#e9f5ff] file:px-4
				file:py-2 file:text-sm
				file:font-semibold file:text-[#40a8f0]
				hover:file:bg-[#bae1ff]
				"
				accept="image/*"
			/>
		</div>
		<h4 class="text-3xl font-bold">Extra</h4>
		<div class="flex flex-col gap-2 sm:flex-row">
			<a
				href="https://taijobi.substack.com/embed"
				target="_blank"
				class="rounded-lg bg-[#40a8f0] px-4 py-2 text-center text-lg font-medium text-white"
			>
				Sign up for Newsletter</a
			>
			<button
				formaction="?/requestPasswordReset"
				class="rounded-lg bg-black px-4 py-2 text-lg font-medium text-white"
			>
				Reset Password
			</button>
		</div>
	</form>
</section>
