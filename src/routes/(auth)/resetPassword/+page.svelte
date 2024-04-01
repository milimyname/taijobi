<script lang="ts">
	import ResetPasswordForm from '$lib/components/forms/reset-password-form.svelte';
	import { superForm } from 'sveltekit-superforms';
	import { zodClient } from 'sveltekit-superforms/adapters';
	import { resetPasswordSchema } from '$lib/utils/zodSchema';

	export let data;

	const form = superForm(data.form, {
		validators: zodClient(resetPasswordSchema)
	});
</script>

<ResetPasswordForm {form} />
