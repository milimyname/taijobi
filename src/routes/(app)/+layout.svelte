<script lang="ts">
	import { IS_DESKTOP } from '$lib/utils/constants';
	import { fly } from 'svelte/transition';
	import { sineIn } from 'svelte/easing';
	import MobileNav from '$lib/components/MobileNav.svelte';
	import { showAppNav, showNav, innerWidthStore, innerHeightStore } from '$lib/utils/stores';
	import { onMount } from 'svelte';
	import image from '$lib/static/taijobi.png';
	import { pocketbase } from '$lib/utils/pocketbase';
	import { Home, LogOut, Newspaper, GraduationCap, Menu } from 'lucide-svelte';

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
		$innerWidthStore > IS_DESKTOP && ($showNav = false);
		$innerWidthStore > IS_DESKTOP && ($showAppNav = false);
	}
</script>

<svelte:window bind:innerWidth={$innerWidthStore} bind:innerHeight={$innerHeightStore} />

<main
	class="relative flex h-screen select-none flex-col-reverse items-center overflow-auto p-5 sm:flex-row"
>
	<nav
		class="{!isLongPress
			? 'w-[90%] p-4'
			: 'right-5 p-2'}  fixed bottom-5 z-40 flex items-center justify-between rounded-full bg-primary p-2 text-white transition-all xm:p-2 sm:relative sm:bottom-0 sm:h-full sm:w-24 sm:flex-col sm:justify-center sm:gap-10 sm:p-5"
	>
		{#if $innerWidthStore > IS_DESKTOP}
			<a href="/" class="mb-auto">
				<img
					src="/taijobi.png"
					class="h-10 w-10 rounded-full shadow-logo sm:h-12 sm:w-12"
					alt="Logo"
				/>
			</a>
			<div class="flex gap-10 sm:flex-col">
				<a href="/">
					<Home class="h-6 w-6" />
				</a>
				<a href="/studying">
					<GraduationCap class="h-6 w-6" />
				</a>
				<a href="/profile">
					<Newspaper class="h-6 w-6" />
				</a>
				<form action="/logout" method="POST">
					<button type="submit">
						<LogOut class="h-6 w-6" />
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
					class="pointer-events-none h-8 w-8 select-none rounded-full shadow-logo hover:h-12 hover:w-12 xm:h-10 xm:w-10 sm:h-12 sm:w-12"
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
					<Menu class="mr-1 xm:h-6 xm:w-6 sm:h-8 sm:w-8" />
				</button>
			{/if}
		{/if}
	</nav>
	<MobileNav />
	<slot />
</main>
