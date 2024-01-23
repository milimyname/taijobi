<script lang="ts">
	import * as Form from '$lib/components/ui/form';
	import { resetPasswordSchema, type ResetPasswordSchema } from '$lib/utils/zodSchema';
	import type { SuperValidated } from 'sveltekit-superforms';

	export let form: SuperValidated<ResetPasswordSchema>;
</script>

<Form.Root
	method="POST"
	{form}
	schema={resetPasswordSchema}
	let:config
	class="flex h-full w-full flex-col  gap-60  p-10 md:gap-0"
>
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

		<Form.Field {config} name="email">
			<Form.Item class="flex w-full flex-col md:w-2/3">
				<Form.Label>Email or username</Form.Label>
				<Form.Input />
				<Form.Validation />
			</Form.Item>
		</Form.Field>

		<Form.Button
			class="text-md w-full rounded-md bg-black py-2 font-medium text-white shadow-lg transition duration-200 visited:-translate-x-4 hover:bg-gray-700 active:translate-y-1 active:shadow-sm md:w-2/3"
		>
			Reset
		</Form.Button>
	</div>
</Form.Root>
