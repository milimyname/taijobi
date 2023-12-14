<script lang="ts">
	import ProgressSlider from './ProgressSlider.svelte';
	import { twSmallScreen } from '$lib/utils/constants';
	import { showNav, innerWidthStore, innerHeightStore } from '$lib/utils/stores';
	import DrawingNav from '$lib/components/DrawingNav.svelte';

	$: $innerWidthStore > twSmallScreen && ($showNav = false);
</script>

<svelte:window bind:innerWidth={$innerWidthStore} bind:innerHeight={$innerHeightStore} />

<main class="relative flex h-[100dvh] select-none flex-col-reverse items-center p-5">
	<DrawingNav />
	<ProgressSlider />
	<slot />
</main>
