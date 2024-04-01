<script lang="ts">
	import SignupForm from '$lib/components/forms/signup-form.svelte';
	import { signupSchema } from '$lib/utils/zodSchema.js';
	import { superForm } from 'sveltekit-superforms';
	import { zodClient } from 'sveltekit-superforms/adapters';

	export let data;

	const form = superForm(data.form, {
		validators: zodClient(signupSchema)
	});
</script>

<SignupForm {form} />
