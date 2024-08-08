<script lang="ts">
	import * as Form from '$lib/components/ui/form';
	import { type ResetPasswordSchema } from '$lib/utils/zodSchema';
	import { type SuperForm, type Infer } from 'sveltekit-superforms';
	import { Input } from '$lib/components/ui/input';

	export let form: SuperForm<Infer<ResetPasswordSchema>>;

	const { form: formData, enhance } = form;
</script>

<form method="POST" use:enhance class="flex h-full w-full flex-col gap-60 p-10 md:gap-0">
	<div class=" flex items-center justify-between">
		<a href="/login">Log in</a>
		<a href="/" class="self-end">
			<img
				src="/taijobi.png"
				class="h-10 w-10 rounded-full shadow-logo sm:h-12 sm:w-12"
				alt="Logo"
			/>
		</a>
	</div>

	<div class="flex flex-col items-center justify-center gap-5 md:flex-1">
		<h1 class="text-3xl font-medium">Reset your password</h1>

		<Form.Field {form} name="email" class="flex w-full flex-col md:w-2/3">
			<Form.Control let:attrs>
				<Form.Label>Email or username</Form.Label>
				<Input {...attrs} bind:value={$formData.email} />
			</Form.Control>
			<Form.FieldErrors />
		</Form.Field>

		<Form.Button
			class="text-md w-full rounded-md bg-black py-2 font-medium text-white shadow-lg transition duration-200 visited:-translate-x-4 hover:bg-gray-700 active:translate-y-1 active:shadow-sm md:w-2/3"
		>
			Reset
		</Form.Button>
	</div>
</form>
