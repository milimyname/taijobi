<script lang="ts">
	import LoginForm from '$lib/components/forms/login-form.svelte';
	import { superForm } from 'sveltekit-superforms';
	import { zodClient } from 'sveltekit-superforms/adapters';
	import { loginSchema } from '$lib/utils/zodSchema';

	export let data;

	const form = superForm(data.form, {
		validators: zodClient(loginSchema)
	});
</script>

<LoginForm
	{form}
	codeVerifier={data.codeVerifier}
	authProviderRedirect={data.authProviderRedirect}
	authProviderState={data.authProviderState}
/>
