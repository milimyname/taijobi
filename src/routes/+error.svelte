<script lang="ts">
	import { page } from '$app/stores';
	import { goto } from '$app/navigation';
	import { Button } from '$lib/components/ui/button';
</script>

<div class="flex h-screen items-center justify-center">
	<div class="text-center">
		<h1 class="mb-4 text-4xl font-medium">
			{$page.status}: {$page.error ? $page.error.message : 'An error occurred'}
		</h1>
		<Button on:click={() => goto('/')}>Go to Home</Button>
	</div>
</div>
