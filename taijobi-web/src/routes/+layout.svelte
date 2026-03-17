<script lang="ts">
	import './layout.css';
	import { init, isReady } from '$lib/wasm';
	import { onMount } from 'svelte';
	import { page } from '$app/state';
	import { updateStore } from '$lib/update.svelte';
	import UpdateBanner from '../components/UpdateBanner.svelte';
	import CharTooltip from '../components/CharTooltip.svelte';

	let { children } = $props();
	let ready = $state(false);
	let error = $state('');

	onMount(async () => {
		try {
			await init();
			ready = true;
			updateStore.init();
		} catch (e) {
			error = e instanceof Error ? e.message : 'Failed to initialize';
			console.error('[taijobi] init error:', e);
		}
	});

	function isActive(path: string): boolean {
		return page.url.pathname === path;
	}

	const pageTitle = $derived(
		page.url.pathname === '/drill'
			? 'Drill'
			: page.url.pathname === '/lexicon'
				? 'Lexikon'
				: page.url.pathname === '/packs'
					? 'Pakete'
					: page.url.pathname.startsWith('/lessons')
						? 'Lektionen'
						: page.url.pathname === '/characters'
							? 'Zeichen'
							: page.url.pathname.startsWith('/character')
								? 'Zeichen'
								: 'Taijobi',
	);
</script>

<svelte:head>
	<meta name="theme-color" content="#195c37" />
	<link rel="manifest" href="/manifest.webmanifest" />
</svelte:head>

{#if error}
	<div class="flex min-h-screen items-center justify-center bg-bg-light text-slate-900">
		<div class="px-6 text-center">
			<p class="text-lg font-semibold text-red-600">Laden fehlgeschlagen</p>
			<p class="mt-2 text-sm text-slate-500">{error}</p>
		</div>
	</div>
{:else if !ready}
	<div class="flex min-h-screen items-center justify-center bg-bg-light">
		<p class="text-lg font-medium text-slate-400">Laden...</p>
	</div>
{:else}
	<div class="relative mx-auto flex min-h-screen max-w-[768px] flex-col bg-bg-light shadow-sm">
		<!-- Update Banner -->
		{#if updateStore.showBanner}
			<button
				onclick={() => (updateStore.sheetOpen = true)}
				class="flex w-full items-center justify-center gap-2 bg-primary px-4 py-2 text-sm font-medium text-white"
			>
				<span class="material-symbols-outlined text-[16px]">sync</span>
				Neue Version verf&uuml;gbar &mdash; tippen zum Aktualisieren
			</button>
		{/if}
		<UpdateBanner />

		<!-- Header -->
		<header
			class="sticky top-0 z-10 flex items-center justify-between border-b border-primary/10 bg-bg-light/80 px-4 py-4 backdrop-blur-md"
		>
			<div class="flex items-center gap-3">
				<div
					class="flex size-10 items-center justify-center overflow-hidden rounded-full border border-primary/20 bg-primary/10"
				>
					<span class="material-symbols-outlined text-primary">person</span>
				</div>
				<div>
					<p class="text-xs font-medium uppercase tracking-wider text-slate-500">Dashboard</p>
					<h2 class="text-lg font-bold leading-tight text-slate-900">{pageTitle}</h2>
				</div>
			</div>
			<button
				class="rounded-full p-2 text-slate-600 transition-colors hover:bg-slate-100"
			>
				<span class="material-symbols-outlined">notifications</span>
			</button>
		</header>

		<!-- Main Content -->
		<main class="flex-1 overflow-y-auto px-4 pb-24">
			{@render children()}
		</main>

		<!-- Bottom Navigation — 3 tabs -->
		<nav
			class="fixed bottom-0 left-0 right-0 z-20 mx-auto max-w-[768px] border-t border-primary/10 bg-bg-light/80 px-6 pb-6 pt-2 backdrop-blur-md"
		>
			<div class="flex items-center justify-between">
				<a
					href="/"
					class="flex flex-col items-center gap-1 {isActive('/') ? 'text-primary' : 'text-slate-400 hover:text-primary'} transition-colors"
				>
					<span class="material-symbols-outlined {isActive('/') ? 'active-icon' : ''}"
						>home</span
					>
					<span class="text-[10px] font-bold uppercase tracking-wider">Start</span>
				</a>
				<a
					href="/drill"
					class="flex flex-col items-center gap-1 {isActive('/drill') ? 'text-primary' : 'text-slate-400 hover:text-primary'} transition-colors"
				>
					<span class="material-symbols-outlined {isActive('/drill') ? 'active-icon' : ''}"
						>style</span
					>
					<span class="text-[10px] font-bold uppercase tracking-wider">&Uuml;ben</span>
				</a>
				<a
					href="/packs"
					class="flex flex-col items-center gap-1 {isActive('/packs') || page.url.pathname.startsWith('/lessons') ? 'text-primary' : 'text-slate-400 hover:text-primary'} transition-colors"
				>
					<span class="material-symbols-outlined {isActive('/packs') || page.url.pathname.startsWith('/lessons') ? 'active-icon' : ''}"
						>inventory_2</span
					>
					<span class="text-[10px] font-bold uppercase tracking-wider">Pakete</span>
				</a>
			</div>
		</nav>
		<CharTooltip />
	</div>
{/if}
