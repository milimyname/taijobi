<script lang="ts">
	import { twSmallScreen } from '$lib/utils/constants';
	import { fly } from 'svelte/transition';
	import { sineIn } from 'svelte/easing';
	import MobileNav from './MobileNav.svelte';
	import { showAppNav, showNav, innerWidthStore } from '$lib/utils/stores';
	import { onMount } from 'svelte';
	import image from '$lib/static/taijobi.png';
	import { icons } from '$lib/utils/icons';
	import { pocketbase } from '$lib/utils/pocketbase';

	let innerWidth: number;
	let longPressTimer: NodeJS.Timeout;
	let isLongPress = false;
	let imageSrc = image;

	export let data;

	function handleUserIconClick() {
		if (!isLongPress) $showNav = !$showNav;
		isLongPress = false; // Reset the long press flag
		$showAppNav = false;
	}

	function handleMenuIconClick() {
		$showAppNav = !$showAppNav;
		$showNav = false;
	}

	function handleLongPress() {
		longPressTimer = setTimeout(() => {
			// alert('long pressed');
			isLongPress = true;
			$showNav = false;
		}, 500);
	}

	function handleCancelPress() {
		clearTimeout(longPressTimer);
		if (isLongPress) {
			// alert('cancelled long press');
		}
	}

	onMount(() => {
		if (data.user.oauth2ImageUrl) imageSrc = data.user.oauth2ImageUrl;
		else if (data.user.avatar) imageSrc = pocketbase.files.getUrl(data.user, data.user.avatar);
		else imageSrc = image;
	});

	$: {
		innerWidth > twSmallScreen && ($showNav = false);
		innerWidth > twSmallScreen && ($showAppNav = false);
		// Set innerWidth to store
		$innerWidthStore = innerWidth;
	}
</script>

<svelte:window bind:innerWidth />

<main class="relative flex h-full select-none flex-col-reverse items-center p-5 sm:flex-row">
	<nav
		class="{!isLongPress
			? 'w-[90%] p-4'
			: 'right-5 p-2'} absolute z-40 flex items-center justify-between rounded-full bg-primary text-white transition-all sm:relative sm:h-full sm:w-auto sm:flex-col sm:justify-center sm:gap-10 sm:p-5"
	>
		{#if innerWidth > twSmallScreen}
			<a href="/" class="mb-auto">
				<img
					src="/taijobi.png"
					class="h-10 w-10 rounded-full shadow-logo sm:h-12 sm:w-12"
					alt="Logo"
				/>
			</a>
			<div class="flex gap-10 sm:flex-col">
				<a href="/signup">{@html icons.signup} </a>
				<a href="/studying">{@html icons.school} </a>
				<a href="/profile">{@html icons.news} </a>
				<form action="/logout" method="POST">
					<button type="submit">
						{@html icons.logout}
					</button>
				</form>
			</div>
			<a href="/profile" class="mt-auto">
				<img src={imageSrc} alt="Logo" class="h-10 w-10 rounded-full shadow-logo sm:h-12 sm:w-12" />
			</a>
		{:else}
			<button
				on:click|preventDefault={handleUserIconClick}
				on:mousedown={handleLongPress}
				on:touchstart={handleLongPress}
				on:mouseup={handleCancelPress}
				on:touchend={handleCancelPress}
				class="select-none transition-transform hover:scale-110"
			>
				<img
					src={imageSrc}
					class="pointer-events-none h-12 w-12 select-none rounded-full shadow-logo hover:h-12 hover:w-12"
					alt="Profile Pic"
				/>
			</button>

			{#if !isLongPress}
				<button
					transition:fly={{
						delay: 0,
						duration: 0,
						opacity: 0,
						x: 100,
						easing: sineIn
					}}
					on:click|preventDefault={handleMenuIconClick}
				>
					{@html icons.menu}
				</button>
			{/if}
		{/if}
	</nav>
	<MobileNav />
	<slot />
</main>
