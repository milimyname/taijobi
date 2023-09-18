<script lang="ts">
	import Vault from '$lib/components/forms/Vault.svelte';
	import { clickedEditFlashcard } from '$lib/utils/stores';
	import { slide } from 'svelte/transition';
	import { quintOut } from 'svelte/easing';

	export let enhance: boolean;
	export let errors;
	export let form;
	export let constraints;
</script>

<Vault {enhance}>
	<h4 class="text-2xl">Create a {$form.name} quiz</h4>
	<h5>Work in progress</h5>
</Vault>
