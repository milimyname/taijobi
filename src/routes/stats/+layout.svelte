<script lang="ts">
	import { goto } from '$app/navigation';
	import { icons } from '$lib/utils/icons';
	import { page } from '$app/stores';
</script>

<svelte:head>
	<title>Stats</title>
	<meta name="description" content="Stats" />
	<meta name="theme-color" content="rgb(0,0,0)" />
</svelte:head>

<main class="flex h-full select-none flex-col items-center overflow-hidden bg-white px-3 py-5">
	<nav class="z-[99] flex w-full p-5">
		<button
			on:click|preventDefault={() =>
				$page.route.id && goto($page.route.id.length < 12 ? '/' : '/stats')}
			class="flex items-center gap-2"
		>
			{@html icons.previous}
			<span>Back</span>
		</button>
	</nav>

	<slot />
</main>
