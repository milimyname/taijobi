<script lang="ts">
	import { IS_DESKTOP } from '$lib/utils/constants';
	import { fly } from 'svelte/transition';
	import { sineIn } from 'svelte/easing';
	import MobileNav from '$lib/components/MobileNav.svelte';
	import {
		showAppNav,
		showNav,
		innerWidthStore,
		searchedWordStore,
		openSearch
	} from '$lib/utils/stores';
	import { onMount } from 'svelte';
	import image from '$lib/static/taijobi.png';
	import { pocketbase } from '$lib/utils/pocketbase';
	import { Home, LogOut, Newspaper, GraduationCap, Menu } from 'lucide-svelte';
	import { cn, getHotkeyPrefix, getRandomKanji } from '$lib/utils.js';
	import * as Command from '$lib/components/ui/command';
	import type { FlashcardType } from '$lib/utils/ambient';

	let longPressTimer: any;
	let isLongPress = false;
	let imageSrc = image;
	let search = '';
	let fetchedData: any[] = getRandomKanji();
	let value: string = fetchedData[0].name;

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

	// Fetch flashcards from the server
	async function fetchFlashcards() {
		if (search === '') return;

		try {
			const res = await fetch('/api/flashcard', {
				method: 'POST',
				body: JSON.stringify({ search })
			});

			if (!res.ok) return new Error('Failed to fetch flashcards');

			const data = await res.json();

			fetchedData = data.flashcards;
		} catch (error) {
			console.error(error);
		}
	}

	onMount(() => {
		if (!data.isLoggedIn) imageSrc = image;
		else if (data.user && data.user.oauth2ImageUrl) imageSrc = data.user.oauth2ImageUrl;
		else if (data.user && data.user.avatar && data.user)
			imageSrc = pocketbase.files.getUrl(data.user, data.user.avatar);
		else imageSrc = image;

		function handleKeydown(e: KeyboardEvent) {
			if (e.key === 'k' && (e.metaKey || e.ctrlKey)) {
				e.preventDefault();
				$openSearch = !$openSearch;
			}
		}

		document.addEventListener('keydown', handleKeydown);
		return () => {
			document.removeEventListener('keydown', handleKeydown);
		};
	});

	$: {
		$innerWidthStore > IS_DESKTOP && ($showNav = false);
		$innerWidthStore > IS_DESKTOP && ($showAppNav = false);
	}

	$: if (search === '') fetchedData = getRandomKanji();

	$: if (search !== '') setTimeout(async () => await fetchFlashcards(), 100);

	$: if (search !== '' && fetchedData.length === 0) value = '';

	$: currentHoveredFlashcard = fetchedData?.find((flashcard) => flashcard.name === value);

	$: fetchedData.length === 1 && (value = fetchedData[0].name);
</script>

<main
	class="grid h-screen select-none grid-cols-1 items-start overflow-auto p-5 lg:grid-cols-[1fr_1fr_6rem]"
>
	<slot />
	<aside
		class="fixed bottom-5 left-0 flex w-full justify-center p-5 pb-0 lg:sticky lg:h-full lg:w-full lg:justify-between lg:p-0"
	>
		<p class="fixed bottom-5 left-5 hidden text-sm text-muted-foreground lg:block">
			Press
			<kbd
				class="pointer-events-none inline-flex h-5 select-none items-center gap-1 rounded border bg-muted px-1.5 font-mono text-[10px] font-medium text-muted-foreground opacity-100"
			>
				<span class="text-xs">{getHotkeyPrefix()}</span>K
			</kbd>
		</p>
		<nav
			class={cn(
				'z-40 flex items-center justify-between gap-40 rounded-full bg-primary p-2 text-white transition-all lg:h-full lg:flex-col lg:justify-center lg:gap-10 lg:p-5',
				isLongPress && 'right-5 p-2'
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
						<button type="submit">
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
							easing: sineIn
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

<Command.Dialog bind:open={$openSearch} bind:value shouldFilter={false}>
	<Command.Input
		bind:value={search}
		placeholder="Find a japanese letter or flashcard by meaning or name"
	/>
	<Command.List>
		<Command.Empty>No results found.</Command.Empty>
		<div class="relative grid grid-cols-3">
			<Command.Group heading="Suggestions" class="overflow-x-hidden border-r">
				{#each fetchedData as flashcard}
					<Command.Item value={flashcard.name} class="flex flex-col items-start gap-0.5">
						<h4 class="font-medium">{flashcard.name}</h4>
						<h4>{flashcard.meaning}</h4>
					</Command.Item>
				{/each}
			</Command.Group>

			{#if currentHoveredFlashcard}
				<div
					class="sticky top-0 col-span-2 flex h-72 flex-col items-center justify-center gap-10 px-2"
				>
					{#if currentHoveredFlashcard.furigana}
						<h2 class="text-center text-4xl">
							{@html currentHoveredFlashcard.furigana}
						</h2>
					{:else}
						<h2 class="text-4xl font-bold">{currentHoveredFlashcard.name}</h2>
					{/if}

					<h3>{currentHoveredFlashcard.meaning}</h3>
					<a
						href={`/search/${value}`}
						on:click={() => {
							$openSearch = false;
							$searchedWordStore = currentHoveredFlashcard;
						}}
						class="underline"
					>
						See more
					</a>
				</div>
			{/if}
		</div>
	</Command.List>
</Command.Dialog>
