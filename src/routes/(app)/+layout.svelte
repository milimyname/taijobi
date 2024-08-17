<script lang="ts">
	import { IS_DESKTOP } from '$lib/utils/constants';
	import { fly } from 'svelte/transition';
	import { sineIn } from 'svelte/easing';
	import MobileNav from '$lib/components/MobileNav.svelte';
	import { showAppNav, showNav, innerWidthStore } from '$lib/utils/stores';
	import { onMount } from 'svelte';
	import image from '$lib/static/taijobi.png';
	import { pocketbase } from '$lib/utils/pocketbase';
	import { Home, LogOut, Newspaper, GraduationCap, Menu } from 'lucide-svelte';
	import { cn } from '$lib/utils';

	let longPressTimer: any;
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

	onMount(async () => {
		if (!data.isLoggedIn) imageSrc = image;
		else if (data.user && data.user.oauth2ImageUrl) imageSrc = data.user.oauth2ImageUrl;
		else if (data.user && data.user.avatar && data.user)
			imageSrc = pocketbase.files.getUrl(data.user, data.user.avatar);
		else imageSrc = image;
	});

	$: {
		$innerWidthStore > IS_DESKTOP && ($showNav = false);
		$innerWidthStore > IS_DESKTOP && ($showAppNav = false);
	}
</script>

<svelte:head>
	<title>Taijobi</title>
	<meta name="Taijobi" content="Taijobi" />
</svelte:head>

<main class="grid grid-cols-1 items-start p-5 md:h-screen lg:grid-cols-[1fr_1fr_6rem]">
	<slot />
	<aside
		class="fixed bottom-5 left-0 flex w-full justify-center p-5 pb-0 lg:sticky lg:h-full lg:w-full lg:justify-between lg:p-0"
	>
		<nav
			class={cn(
				'z-40 flex items-center justify-between gap-40 rounded-full bg-primary p-2 text-white transition-all lg:h-full lg:flex-col lg:justify-center lg:gap-10 lg:p-5',
				isLongPress && 'right-5 p-2',
			)}
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
						<Home class="size-6" />
					</a>
					<a href="/">
						<GraduationCap class="size-6" />
					</a>
					<a href="/profile">
						<Newspaper class="size-6" />
					</a>
					<form action="/logout" method="POST">
						<button type="submit" on:click={() => localStorage.clear()}>
							<LogOut class="size-6" />
						</button>
					</form>
				</div>
				<a href="/profile" class="mt-auto">
					<img src={imageSrc} alt="Logo" class="size-10 rounded-full shadow-logo sm:size-12" />
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
						class="pointer-events-none size-8 select-none rounded-full shadow-logo hover:h-12 hover:w-12 xm:size-10 sm:size-12"
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
							easing: sineIn,
						}}
						on:click|preventDefault={handleMenuIconClick}
					>
						<Menu class="mr-1 xm:size-6 sm:size-8" />
					</button>
				{/if}
			{/if}
		</nav>
		<MobileNav />
	</aside>
</main>
