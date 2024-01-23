<script lang="ts">
	import LoginForm from '$lib/components/forms/login-form.svelte';
	export let data;
</script>

<LoginForm
	form={data.form}
	codeVerifier={data.codeVerifier}
	authProviderRedirect={data.authProviderRedirect}
	authProviderState={data.authProviderState}
/>
