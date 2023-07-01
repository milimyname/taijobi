<script lang="ts">
	import { superForm } from 'sveltekit-superforms/client';

	export let data;

	// Client API:
	const { form, errors, constraints, enhance } = superForm(data.form);
</script>

<form
	method="POST"
	use:enhance
	class="flex h-1/2 w-1/2 flex-col items-center justify-center gap-10 rounded-sm bg-slate-400 p-20"
>
	<fieldset>
		<label for="name">Email</label>
		<input
			type="text"
			name="email"
			aria-invalid={$errors.email ? 'true' : undefined}
			bind:value={$form.email}
			{...$constraints.email}
		/>
		{#if $errors.email}<span class="invalid">{$errors.email}</span>{/if}
	</fieldset>

	<fieldset>
		<label for="password">Password</label>
		<input
			type="password"
			name="password"
			aria-invalid={$errors.password ? 'true' : undefined}
			bind:value={$form.password}
			{...$constraints.password}
		/>
		{#if $errors.password}<span class="invalid">{$errors.password}</span>{/if}
	</fieldset>
	<fieldset>
		<label for="passwordConfirm">Confirm Password</label>
		<input
			type="password"
			name="passwordConfirm"
			aria-invalid={$errors.passwordConfirm ? 'true' : undefined}
			bind:value={$form.passwordConfirm}
			{...$constraints.passwordConfirm}
		/>
		{#if $errors.passwordConfirm}<span class="invalid">{$errors.passwordConfirm}</span>{/if}
	</fieldset>

	<button>Submit</button>
</form>

<style>
	.invalid {
		color: red;
	}
</style>
