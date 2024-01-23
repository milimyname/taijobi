<script lang="ts">
	import * as Form from '$lib/components/ui/form';
	import { signupSchema, type SignupSchema } from '$lib/utils/zodSchema';
	import type { SuperValidated } from 'sveltekit-superforms';

	export let form: SuperValidated<SignupSchema>;
</script>

<Form.Root
	method="POST"
	{form}
	schema={signupSchema}
	let:config
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
			<p>Start a journey!</p>
		</div>

		<Form.Field {config} name="email">
			<Form.Item class="flex w-full flex-col md:w-2/3">
				<Form.Label>Email</Form.Label>
				<Form.Input />
				<Form.Validation />
			</Form.Item>
		</Form.Field>

		<Form.Field {config} name="password">
			<Form.Item class="flex w-full flex-col md:w-2/3">
				<Form.Label>Password</Form.Label>
				<Form.Input />
				<Form.Validation />
			</Form.Item>
		</Form.Field>

		<Form.Field {config} name="confirmPassword">
			<Form.Item class="flex w-full flex-col md:w-2/3">
				<Form.Label>Confirm password</Form.Label>
				<Form.Input />
				<Form.Validation />
			</Form.Item>
		</Form.Field>

		<Form.Button
			class="text-md w-full rounded-md bg-black py-2 font-medium text-white shadow-lg transition duration-200 visited:-translate-x-4 hover:bg-gray-700 active:translate-y-1 active:shadow-sm md:w-2/3"
		>
			Sign up
		</Form.Button>

		<p class=" text-center text-xs">
			By clicking continue, you agree to our
			<a href="/" class="font-medium underline"> Terms of Service </a>
			and
			<a href="/" class="font-medium underline">Privacy Policy</a>.
		</p>
	</div>
</Form.Root>
