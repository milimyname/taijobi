<script lang="ts">
	import { superForm } from 'sveltekit-superforms';
	import { slide } from 'svelte/transition';
	import { quintOut } from 'svelte/easing';
	import { loginSchema } from '$lib/utils/zodSchema';
	import { zodClient } from 'sveltekit-superforms/adapters';

	export let data;
	let disabledPasswordConstraint = false;

	// Client API:
	const { form, errors, constraints, enhance } = superForm(data.form, {
		validators: zodClient(loginSchema),
	});
</script>

<form
	use:enhance
	method="POST"
	class="flex h-full w-full flex-col justify-center gap-24 p-10 md:gap-0"
>
	<div class="flex flex-col items-center justify-center gap-5 md:flex-1">
		<h1 class="text-3xl font-medium">Log in as an admin</h1>
		<fieldset class="flex w-full flex-col md:w-2/3">
			<label for="name" class="hidden">Email</label>
			<input
				type="text"
				name="email"
				type='email'
				placeholder="Email"
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
			{#if $errors.email}
				<span
					transition:slide={{ delay: 0, duration: 300, easing: quintOut, axis: 'y' }}
					class="mt-1 select-none text-sm text-red-400">{$errors.email}</span
				>
			{/if}
		</fieldset>
		<fieldset class="flex w-full flex-col md:w-2/3">
			<label for="password" class="hidden">Password</label>
			<input
				type="password"
				name="password"
				placeholder="Password"
				class="
					block
					rounded-md
					border-gray-300
					shadow-sm
					focus:border-indigo-300 focus:ring focus:ring-indigo-200 focus:ring-opacity-50
				"
				aria-invalid={$errors.password ? 'true' : undefined}
				bind:value={$form.password}
				{...!disabledPasswordConstraint ? $constraints.password : {}}
			/>

			{#if $errors.password}
				<span
					transition:slide={{ delay: 0, duration: 300, easing: quintOut, axis: 'y' }}
					class="mt-1 select-none text-sm text-red-400">{$errors.password}</span
				>
			{/if}
		</fieldset>
		<button
			class="text-md w-full rounded-md bg-black py-2 font-medium text-white shadow-lg transition duration-200 visited:-translate-x-4 hover:bg-gray-700 active:translate-y-1 active:shadow-sm md:w-2/3"
			>Log in</button
		>
	</div>
</form>
