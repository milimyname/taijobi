<script lang="ts">
	import ResetPasswordForm from '$lib/components/forms/reset-password-form.svelte';

	export let data;
</script>

<ResetPasswordForm form={data.form} />

<!-- <form
	action="?/signUp"
	method="POST"
	use:enhance
	class="flex h-full w-full flex-col gap-24 p-10 md:gap-0"
>
	<div class="tex flex items-center justify-between">
		<a href="/login">Log in</a>
		<a href="/" class=" self-end">
			<img
				src="/taijobi.png"
				class="h-10 w-10 rounded-full shadow-logo sm:h-12 sm:w-12"
				alt="Logo"
			/>
		</a>
	</div>
	<div class="flex flex-col items-center justify-center gap-5 md:flex-1">
		<div class="text-center">
			<h1 class="text-3xl font-medium">Create an account</h1>
			<p>Enter ur email below to create ur account</p>
		</div>
		<fieldset class="flex w-full flex-col md:w-2/3">
			<label for="name" class="hidden">Email</label>
			<input
				type="text"
				name="email"
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
			{#if $errors.email}<span
					transition:slide={{ delay: 0, duration: 300, easing: quintOut, axis: 'y' }}
					class="mt-1 select-none text-sm text-red-400">{$errors.email}</span
				>{/if}
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
				{...$constraints.password}
			/>
			{#if $errors.password}<span
					transition:slide={{ delay: 0, duration: 300, easing: quintOut, axis: 'y' }}
					class="mt-1 select-none text-sm text-red-400">{$errors.password}</span
				>{/if}
		</fieldset>
		<fieldset class="flex w-full flex-col md:w-2/3">
			<label for="passwordConfirm" class="hidden">Confirm Password</label>
			<input
				type="password"
				name="passwordConfirm"
				placeholder="Confirm Password"
				class="
                    block
                    rounded-md
					border-gray-300
                    shadow-sm
                     focus:border-indigo-300 focus:ring focus:ring-indigo-200 focus:ring-opacity-50
                  "
				aria-invalid={$errors.passwordConfirm ? 'true' : undefined}
				bind:value={$form.passwordConfirm}
				{...$constraints.passwordConfirm}
			/>
			{#if $errors.passwordConfirm}<span
					transition:slide={{ delay: 0, duration: 300, easing: quintOut, axis: 'y' }}
					class="mt-1 select-none text-sm text-red-400">{$errors.passwordConfirm}</span
				>{/if}
		</fieldset>
		<button
			type="submit"
			class="text-md w-full rounded-md bg-black py-2 font-medium text-white shadow-lg transition duration-200 visited:-translate-x-4 hover:bg-gray-700 active:translate-y-1 active:shadow-sm lg:w-2/3"
			>Sign up</button
		>
		<p class=" text-center text-xs">
			By clicking continue, you agree to our <a href="/" class="font-medium underline">
				Terms of Service</a
			>
			and
			<a href="/" class="font-medium underline">Privacy Policy</a>.
		</p>
	</div>
</form> -->
