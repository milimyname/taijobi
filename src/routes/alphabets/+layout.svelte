<script lang="ts">
	import ProgressSlider from './ProgressSlider.svelte';
	import { twSmallScreen } from '$lib/utils/constants';
	import { showNav, innerWidthStore } from '$lib/utils/stores';
	import DrawingNav from './DrawingNav.svelte';

	let innerWidth: number;
	$: {
		innerWidth > twSmallScreen && ($showNav = false);
		// Set innerWidth to store
		$innerWidthStore = innerWidth;
	}
</script>

<svelte:window bind:innerWidth />

<main class="relative flex h-full select-none flex-col-reverse items-center p-5">
	<DrawingNav />
	<ProgressSlider />
	<slot />
</main>
