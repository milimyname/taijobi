<script lang="ts">
	import SignupForm from '$lib/components/forms/signup-form.svelte';

	export let data;
</script>

<SignupForm form={data.form} />
