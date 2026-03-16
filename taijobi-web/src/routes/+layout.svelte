<script lang="ts">
	import './layout.css';
	import { init, isReady } from '$lib/wasm';
	import { onMount } from 'svelte';
	import { page } from '$app/state';

	let { children } = $props();
	let ready = $state(false);
	let error = $state('');

	onMount(async () => {
		try {
			await init();
			ready = true;
		} catch (e) {
			error = e instanceof Error ? e.message : 'Failed to initialize';
			console.error('[taijobi] init error:', e);
		}
	});

	function isActive(path: string): boolean {
		return page.url.pathname === path;
	}
</script>

<svelte:head>
	<meta name="theme-color" content="#2d6a4f" />
	<link rel="manifest" href="/manifest.webmanifest" />
</svelte:head>

{#if error}
	<div class="flex min-h-screen items-center justify-center bg-bg-light text-stone-900">
		<div class="text-center px-6">
			<p class="text-lg font-semibold text-red-600">Failed to load</p>
			<p class="mt-2 text-sm text-stone-500">{error}</p>
		</div>
	</div>
{:else if !ready}
	<div class="flex min-h-screen items-center justify-center bg-bg-light">
		<p class="text-lg text-stone-400 font-medium">Loading...</p>
	</div>
{:else}
	<div class="relative mx-auto flex min-h-screen max-w-md flex-col bg-bg-light">
		<!-- Header -->
		<header
			class="sticky top-0 z-10 flex items-center justify-between border-b border-border-subtle bg-bg-light/80 px-6 py-4 backdrop-blur-md"
		>
			<div class="flex flex-col">
				<span class="text-[10px] font-bold uppercase tracking-[0.15em] text-stone-400"
					>TAIJOBI</span
				>
				<h2 class="text-xl font-semibold tracking-tight">
					{page.url.pathname === '/drill' ? 'Review' : 'Today'}
				</h2>
			</div>
			<div class="flex items-center gap-3">
				<button
					class="flex size-9 items-center justify-center rounded-full bg-stone-100 text-stone-600"
				>
					<span class="material-symbols-outlined text-[20px]">search</span>
				</button>
			</div>
		</header>

		<!-- Main Content -->
		<main class="flex-1 overflow-y-auto px-6 pb-24">
			{@render children()}
		</main>

		<!-- Bottom Navigation -->
		<nav
			class="fixed bottom-0 left-0 right-0 z-20 mx-auto max-w-md border-t border-border-subtle bg-bg-light/95 px-6 pb-6 pt-3 backdrop-blur-xl"
		>
			<div class="flex items-center justify-between">
				<a
					href="/"
					class="flex flex-col items-center gap-1.5 {isActive('/') ? 'text-primary' : 'text-stone-400 hover:text-primary'} transition-colors"
				>
					<span class="material-symbols-outlined {isActive('/') ? 'active-icon' : ''}">home</span
					>
					<span class="text-[10px] font-bold uppercase tracking-wide">Today</span>
				</a>
				<a
					href="/drill"
					class="flex flex-col items-center gap-1.5 {isActive('/drill') ? 'text-primary' : 'text-stone-400 hover:text-primary'} transition-colors"
				>
					<span class="material-symbols-outlined {isActive('/drill') ? 'active-icon' : ''}"
						>auto_stories</span
					>
					<span class="text-[10px] font-bold uppercase tracking-wide">Review</span>
				</a>
				<a
					href="/"
					class="flex flex-col items-center gap-1.5 text-stone-400 hover:text-primary transition-colors"
				>
					<span class="material-symbols-outlined">analytics</span>
					<span class="text-[10px] font-bold uppercase tracking-wide">Insights</span>
				</a>
				<a
					href="/"
					class="flex flex-col items-center gap-1.5 text-stone-400 hover:text-primary transition-colors"
				>
					<span class="material-symbols-outlined">settings</span>
					<span class="text-[10px] font-bold uppercase tracking-wide">Settings</span>
				</a>
			</div>
		</nav>
	</div>
{/if}
