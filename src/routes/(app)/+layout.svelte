<script lang="ts">
	import { twSmallScreen } from '$lib/utils/constants';
	import { fly } from 'svelte/transition';
	import { sineIn } from 'svelte/easing';

	let innerWidth: number;
	let longPressTimer: NodeJS.Timeout;
	let isLongPress = false;
	let showNav = false;

	export let data;

	function handleClick() {
		if (!isLongPress) showNav = !showNav;
		isLongPress = false; // Reset the long press flag
	}

	function handleLongPress() {
		longPressTimer = setTimeout(() => {
			// alert('long pressed');
			isLongPress = true;
			showNav = false;
		}, 500);
	}

	function handleCancelPress() {
		clearTimeout(longPressTimer);
		if (isLongPress) {
			// alert('cancelled long press');
		}
	}

	$: innerWidth > twSmallScreen && (showNav = false);
</script>

<svelte:window bind:innerWidth />

<main class="relative flex h-full select-none flex-col-reverse items-center p-5 sm:flex-row">
	<nav
		class="{!isLongPress
			? 'w-full p-4'
			: 'ml-auto p-2'} z-20 flex items-center justify-between rounded-full bg-primary text-white transition-all sm:h-full sm:w-auto sm:flex-col sm:justify-center sm:gap-10 sm:p-5"
	>
		{#if innerWidth > twSmallScreen}
			<a href="/" class="mb-auto">
				<img src="/taijobi.png" class="h-10 w-10 sm:h-12 sm:w-12" alt="Logo" />
			</a>
			<div class="flex gap-10 sm:flex-col">
				<a href="/signup">
					<svg
						xmlns="http://www.w3.org/2000/svg"
						fill="none"
						viewBox="0 0 24 24"
						stroke-width="1.5"
						stroke="currentColor"
						class="h-6 w-6"
					>
						<path
							stroke-linecap="round"
							stroke-linejoin="round"
							d="M2.25 12l8.954-8.955c.44-.439 1.152-.439 1.591 0L21.75 12M4.5 9.75v10.125c0 .621.504 1.125 1.125 1.125H9.75v-4.875c0-.621.504-1.125 1.125-1.125h2.25c.621 0 1.125.504 1.125 1.125V21h4.125c.621 0 1.125-.504 1.125-1.125V9.75M8.25 21h8.25"
						/>
					</svg>
				</a>
				<a href="/saved"
					><svg
						xmlns="http://www.w3.org/2000/svg"
						fill="none"
						viewBox="0 0 24 24"
						stroke-width="1.5"
						stroke="currentColor"
						class="h-6 w-6"
					>
						<path
							stroke-linecap="round"
							stroke-linejoin="round"
							d="M3.75 9.776c.112-.017.227-.026.344-.026h15.812c.117 0 .232.009.344.026m-16.5 0a2.25 2.25 0 00-1.883 2.542l.857 6a2.25 2.25 0 002.227 1.932H19.05a2.25 2.25 0 002.227-1.932l.857-6a2.25 2.25 0 00-1.883-2.542m-16.5 0V6A2.25 2.25 0 016 3.75h3.879a1.5 1.5 0 011.06.44l2.122 2.12a1.5 1.5 0 001.06.44H18A2.25 2.25 0 0120.25 9v.776"
						/>
					</svg>
				</a>
				<a href="/news"
					><svg
						xmlns="http://www.w3.org/2000/svg"
						fill="none"
						viewBox="0 0 24 24"
						stroke-width="1.5"
						stroke="currentColor"
						class="h-6 w-6"
					>
						<path
							stroke-linecap="round"
							stroke-linejoin="round"
							d="M12 7.5h1.5m-1.5 3h1.5m-7.5 3h7.5m-7.5 3h7.5m3-9h3.375c.621 0 1.125.504 1.125 1.125V18a2.25 2.25 0 01-2.25 2.25M16.5 7.5V18a2.25 2.25 0 002.25 2.25M16.5 7.5V4.875c0-.621-.504-1.125-1.125-1.125H4.125C3.504 3.75 3 4.254 3 4.875V18a2.25 2.25 0 002.25 2.25h13.5M6 7.5h3v3H6v-3z"
						/>
					</svg>
				</a>
				<form action="/logout" method="POST">
					<button type="submit">
						<svg
							xmlns="http://www.w3.org/2000/svg"
							fill="none"
							viewBox="0 0 24 24"
							stroke-width="1.5"
							stroke="currentColor"
							class="h-6 w-6"
						>
							<path
								stroke-linecap="round"
								stroke-linejoin="round"
								d="M15.75 9V5.25A2.25 2.25 0 0013.5 3h-6a2.25 2.25 0 00-2.25 2.25v13.5A2.25 2.25 0 007.5 21h6a2.25 2.25 0 002.25-2.25V15m3 0l3-3m0 0l-3-3m3 3H9"
							/>
						</svg>
					</button>
				</form>
			</div>
			<a href="/" class="mt-auto">
				<img src="/taijobi.png" alt="Logo" />
			</a>
		{:else}
			<button
				on:click={handleClick}
				on:mousedown={handleLongPress}
				on:touchstart={handleLongPress}
				on:mouseup={handleCancelPress}
				on:touchend={handleCancelPress}
				class="select-none transition-transform hover:scale-110"
			>
				<img
					src={data.user ? data.user.oauth2ImageUrl : '/mili.jpeg'}
					class="pointer-events-none h-12 w-12 select-none rounded-full hover:h-12 hover:w-12"
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
				>
					<svg
						xmlns="http://www.w3.org/2000/svg"
						fill="none"
						viewBox="0 0 24 24"
						stroke-width="1.5"
						stroke="currentColor"
						class="h-8 w-8"
					>
						<path
							stroke-linecap="round"
							stroke-linejoin="round"
							d="M3.75 6.75h16.5M3.75 12h16.5m-16.5 5.25h16.5"
						/>
					</svg>
				</button>
			{/if}
		{/if}
	</nav>
	{#if showNav}
		<div
			class="absolute bottom-20 z-10 w-full p-5"
			transition:fly={{
				delay: 0,
				duration: 500,
				opacity: 0,
				y: 50,
				easing: sineIn
			}}
		>
			<div class="-mb-52 h-[17rem] w-full rounded-4xl border-4 border-[#bddffa] shadow-xl">
				<a href="/" class="flex justify-between p-4" on:click={() => (showNav = false)}>
					<svg
						xmlns="http://www.w3.org/2000/svg"
						fill="none"
						viewBox="0 0 24 24"
						stroke-width="1.5"
						stroke="currentColor"
						class="h-8 w-8"
					>
						<path
							stroke-linecap="round"
							stroke-linejoin="round"
							d="M9.879 7.519c1.171-1.025 3.071-1.025 4.242 0 1.172 1.025 1.172 2.687 0 3.712-.203.179-.43.326-.67.442-.745.361-1.45.999-1.45 1.827v.75M21 12a9 9 0 11-18 0 9 9 0 0118 0zm-9 5.25h.008v.008H12v-.008z"
						/>
					</svg>
					<h4 class="text-xl font-medium">Taijobi</h4>
				</a>
			</div>
			<div class="-mb-36 h-52 w-full rounded-4xl border-4 border-[#82c5f7] shadow-pricing">
				<a href="/" class=" flex justify-between p-4" on:click={() => (showNav = false)}>
					<svg
						xmlns="http://www.w3.org/2000/svg"
						fill="none"
						viewBox="0 0 24 24"
						stroke-width="1.5"
						stroke="currentColor"
						class="h-8 w-8"
					>
						<path
							stroke-linecap="round"
							stroke-linejoin="round"
							d="M2.25 8.25h19.5M2.25 9h19.5m-16.5 5.25h6m-6 2.25h3m-3.75 3h15a2.25 2.25 0 002.25-2.25V6.75A2.25 2.25 0 0019.5 4.5h-15a2.25 2.25 0 00-2.25 2.25v10.5A2.25 2.25 0 004.5 19.5z"
						/>
					</svg>

					<h4 class="text-xl font-medium">Pricing</h4>
				</a>
			</div>
			<div class="-mb-20 h-36 w-full rounded-4xl border-4 border-[#40a8f0] shadow-profile">
				<a href="/profile" class="flex justify-between p-4" on:click={() => (showNav = false)}>
					<svg
						xmlns="http://www.w3.org/2000/svg"
						fill="none"
						viewBox="0 0 24 24"
						stroke-width="1.5"
						stroke="currentColor"
						class="h-8 w-8"
					>
						<path
							stroke-linecap="round"
							stroke-linejoin="round"
							d="M17.982 18.725A7.488 7.488 0 0012 15.75a7.488 7.488 0 00-5.982 2.975m11.963 0a9 9 0 10-11.963 0m11.963 0A8.966 8.966 0 0112 21a8.966 8.966 0 01-5.982-2.275M15 9.75a3 3 0 11-6 0 3 3 0 016 0z"
						/>
					</svg>
					<h4 class="text-xl font-medium">Profile</h4>
				</a>
			</div>
		</div>
	{/if}
	<slot />
</main>
