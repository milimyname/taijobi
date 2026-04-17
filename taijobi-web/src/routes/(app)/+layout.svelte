<script lang="ts">
	import BarChart from '$lib/icons/BarChart.svelte';
	import Book2 from '$lib/icons/Book2.svelte';
	import Dictionary from '$lib/icons/Dictionary.svelte';
	import Explore from '$lib/icons/Explore.svelte';
	import Home from '$lib/icons/Home.svelte';
	import Inventory2 from '$lib/icons/Inventory2.svelte';
	import Language from '$lib/icons/Language.svelte';
	import Person from '$lib/icons/Person.svelte';
	import Search from '$lib/icons/Search.svelte';
	import Settings from '$lib/icons/Settings.svelte';
	import Style from '$lib/icons/Style.svelte';
	import Sync from '$lib/icons/Sync.svelte';
	import Translate from '$lib/icons/Translate.svelte';
	import './layout.css';
	import { init, isReady, setOnDataChanged } from '$lib/wasm';
	import { onMount, onDestroy } from 'svelte';
	import { connectSync, disconnectSync, isSyncEnabled } from '$lib/sync';
	import { data } from '$lib/data.svelte';
	import { page } from '$app/state';
	import { goto } from '$app/navigation';
	import { onboardingStore } from '$lib/onboarding.svelte';
	import { streakBannerStore } from '$lib/streak-banner.svelte';
	import { pushStore } from '$lib/push.svelte';
	import Download from '$lib/icons/Download.svelte';
	import { downloadStore } from '$lib/download-state.svelte';
	import { updateStore } from '$lib/update.svelte';
	import { themeStore } from '$lib/theme.svelte';
	import { LS_DEVTOOLS } from '$lib/config';
	import UpdateBanner from '../../components/UpdateBanner.svelte';
	import CharTooltip from '../../components/CharTooltip.svelte';
	import Toast from '../../components/Toast.svelte';
	import DevTools from '../../components/DevTools.svelte';
	import CommandPalette from '../../components/CommandPalette.svelte';
	import { paletteStore } from '$lib/commandPalette.svelte';

	let { children } = $props();
	let ready = $state(false);
	let error = $state('');
	let showShortcuts = $state(false);

	// DevTools gating — persisted in localStorage so it survives reloads.
	// ?devtools (any value) turns it on for this + future sessions;
	// ?devtools=off clears the flag.
	let devtoolsEnabled = $state(false);
	$effect(() => {
		const param = page.url.searchParams.get('devtools');
		if (param === 'off' || param === '0' || param === 'false') {
			localStorage.removeItem(LS_DEVTOOLS);
			devtoolsEnabled = false;
		} else if (page.url.searchParams.has('devtools')) {
			localStorage.setItem(LS_DEVTOOLS, '1');
			devtoolsEnabled = true;
		} else {
			devtoolsEnabled = localStorage.getItem(LS_DEVTOOLS) === '1';
		}
	});

	// Onboarding dictionary install state (uses global downloadStore so progress
	// survives if the user skips the onboarding modal mid-download).
	let zhLoaded = $derived(data.chineseDataLoaded());
	let enLoaded = $derived(data.endictLoaded());
	let deLoaded = $derived(data.dedictLoaded());

	onMount(async () => {
		try {
			themeStore.init();
			await init();
			ready = true;
			updateStore.init();
			onboardingStore.init();
			streakBannerStore.init();
			pushStore.init();
			pushStore.heartbeat();
			setOnDataChanged(() => queueMicrotask(() => data.bump()));
			if (isSyncEnabled()) connectSync();
		} catch (e) {
			error = e instanceof Error ? e.message : 'Failed to initialize';
			console.error('[taijobi] init error:', e);
		}
		window.addEventListener('keydown', onKeydown);
	});

	onDestroy(() => {
		disconnectSync();
		if (typeof window !== 'undefined') window.removeEventListener('keydown', onKeydown);
	});

	let lastKey = '';
	let lastKeyAt = 0;

	function onKeydown(e: KeyboardEvent) {
		// Cmd+K / Ctrl+K opens the command palette from anywhere
		if ((e.metaKey || e.ctrlKey) && e.key === 'k') {
			e.preventDefault();
			paletteStore.toggle();
			return;
		}
		// Ignore when typing in inputs/textareas/contenteditable
		const t = e.target as HTMLElement | null;
		if (t && (t.tagName === 'INPUT' || t.tagName === 'TEXTAREA' || t.isContentEditable)) return;
		if (e.metaKey || e.ctrlKey || e.altKey) return;

		if (e.key === '?') {
			e.preventDefault();
			showShortcuts = !showShortcuts;
			return;
		}
		if (e.key === 'Escape' && showShortcuts) {
			showShortcuts = false;
			return;
		}

		// "g" then nav key — vim-style chord
		const now = Date.now();
		if (lastKey === 'g' && now - lastKeyAt < 1000) {
			lastKey = '';
			const map: Record<string, string> = {
				h: '/home',
				d: '/drill',
				l: '/lexicon',
				p: '/packs',
				s: '/stats',
				w: '/dictionary',
				e: '/settings',
				c: '/characters',
			};
			const path = map[e.key];
			if (path) {
				e.preventDefault();
				goto(path);
			}
			return;
		}
		if (e.key === 'g') {
			lastKey = 'g';
			lastKeyAt = now;
		} else {
			lastKey = '';
		}
	}

	function isActive(path: string): boolean {
		return page.url.pathname === path;
	}

	/** Like isActive but also matches child paths, e.g. /packs matches /packs/hsk3.
	 *  Used by the desktop sidebar so a lesson or character detail page keeps
	 *  the parent nav link highlighted. */
	function isActiveSection(path: string): boolean {
		const p = page.url.pathname;
		if (p === path) return true;
		if (p.startsWith(path + '/')) return true;
		// /characters is the list, /character/:ch is the detail — keep them in sync.
		if (path === '/characters' && p.startsWith('/character/')) return true;
		return false;
	}

	const pageTitle = $derived(
		page.url.pathname === '/drill'
			? 'Drill'
			: page.url.pathname === '/lexicon/import'
				? 'Kindle-Import'
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
								: page.url.pathname === '/dictionary'
									? 'Wörterbuch'
									: page.url.pathname === '/stats'
										? 'Statistik'
										: page.url.pathname === '/settings'
											? 'Einstellungen'
											: page.url.pathname === '/about'
												? 'Über'
												: page.url.pathname === '/more'
													? 'Mehr'
													: 'Taijobi',
	);

	// Routes that live under the "Mehr" tab — used to highlight it as active.
	const MORE_ROUTES = [
		'/more',
		'/stats',
		'/dictionary',
		'/packs',
		'/lessons',
		'/lexicon',
		'/characters',
		'/character',
		'/settings',
		'/about'
	];

	function isMoreActive(): boolean {
		return MORE_ROUTES.some(
			(r) => page.url.pathname === r || page.url.pathname.startsWith(r + '/')
		);
	}
</script>

<svelte:head>
	<meta name="theme-color" content={themeStore.isDark ? '#131f18' : '#195c37'} />
	<link rel="manifest" href="/manifest.webmanifest" />
</svelte:head>

{#if error}
	<div class="flex min-h-screen items-center justify-center bg-bg-light text-slate-900 dark:bg-bg-dark dark:text-slate-100">
		<div class="px-6 text-center">
			<p class="text-lg font-semibold text-red-600">Laden fehlgeschlagen</p>
			<p class="mt-2 text-sm text-slate-500 dark:text-slate-400">{error}</p>
		</div>
	</div>
{:else if !ready}
	<div class="flex min-h-screen flex-col items-center justify-center gap-6 bg-bg-light dark:bg-bg-dark">
		<div class="flex flex-col items-center gap-3">
			<div class="loading-pulse flex size-16 items-center justify-center rounded-2xl bg-primary/10">
				<Translate class="text-primary" style="font-size: 32px" />
			</div>
			<h1 class="text-xl font-bold text-slate-900 dark:text-slate-100">Taijobi</h1>
			<p class="text-sm text-slate-400 dark:text-slate-500">Wird geladen...</p>
		</div>
		<div class="h-1 w-48 overflow-hidden rounded-full bg-slate-100 dark:bg-white/10">
			<div class="loading-bar h-full rounded-full bg-primary"></div>
		</div>
	</div>
{:else}
	<div class="relative mx-auto flex min-h-screen max-w-[768px] flex-col bg-bg-light shadow-sm dark:bg-bg-dark lg:max-w-[1080px] lg:flex-row lg:shadow-none">
		<!-- Desktop Sidebar — hidden below lg, persistent on desktop -->
		<aside
			class="hidden lg:sticky lg:top-0 lg:flex lg:h-screen lg:w-60 lg:shrink-0 lg:flex-col lg:overflow-y-auto lg:border-r lg:border-primary/10 lg:px-4 lg:py-6"
		>
			<a href="/home" class="mb-6 flex items-center gap-2.5 px-2">
				<div class="flex size-9 items-center justify-center rounded-xl bg-primary/10">
					<Translate class="text-primary" />
				</div>
				<span class="text-lg font-bold text-slate-900 dark:text-slate-100">Taijobi</span>
			</a>

			<nav class="flex-1 space-y-0.5">
				{#each [
					{ href: '/home', label: 'Start', Icon: Home },
					{ href: '/drill', label: 'Üben', Icon: Style },
				] as item (item.href)}
					<a
						href={item.href}
						class="flex items-center gap-3 rounded-xl px-3 py-2 text-sm font-medium transition-colors {isActiveSection(
							item.href,
						)
							? 'bg-primary/10 text-primary'
							: 'text-slate-600 hover:bg-slate-100 dark:text-slate-300 dark:hover:bg-white/5'}"
					>
						<item.Icon />
						{item.label}
					</a>
				{/each}

				<div class="my-3 border-t border-slate-100 dark:border-white/5"></div>

				{#each [
					{ href: '/dictionary', label: 'Wörterbuch', Icon: Dictionary },
					{ href: '/stats', label: 'Statistik', Icon: BarChart },
					{ href: '/packs', label: 'Pakete', Icon: Inventory2 },
					{ href: '/lexicon', label: 'Lexikon', Icon: Book2 },
					{ href: '/characters', label: 'Zeichen', Icon: Language },
				] as item (item.href)}
					<a
						href={item.href}
						class="flex items-center gap-3 rounded-xl px-3 py-2 text-sm font-medium transition-colors {isActiveSection(
							item.href,
						)
							? 'bg-primary/10 text-primary'
							: 'text-slate-600 hover:bg-slate-100 dark:text-slate-300 dark:hover:bg-white/5'}"
					>
						<item.Icon />
						{item.label}
					</a>
				{/each}

				<div class="my-3 border-t border-slate-100 dark:border-white/5"></div>

				{#each [
					{ href: '/settings', label: 'Einstellungen', Icon: Settings },
					{ href: '/about', label: 'Über', Icon: Person },
				] as item (item.href)}
					<a
						href={item.href}
						class="flex items-center gap-3 rounded-xl px-3 py-2 text-sm font-medium transition-colors {isActiveSection(
							item.href,
						)
							? 'bg-primary/10 text-primary'
							: 'text-slate-600 hover:bg-slate-100 dark:text-slate-300 dark:hover:bg-white/5'}"
					>
						<item.Icon />
						{item.label}
					</a>
				{/each}
			</nav>

			<button
				type="button"
				onclick={() => paletteStore.show()}
				class="mt-4 flex items-center gap-3 rounded-xl border border-slate-200 bg-white px-3 py-2 text-sm font-medium text-slate-500 transition-colors hover:border-primary/30 hover:text-primary dark:border-white/10 dark:bg-white/5 dark:text-slate-400"
			>
				<Search />
				<span>Suchen</span>
				<kbd
					class="ml-auto rounded-md border border-slate-200 bg-slate-50 px-1.5 py-0.5 font-mono text-[10px] text-slate-500 dark:border-white/10 dark:bg-white/5"
					>⌘K</kbd
				>
			</button>
		</aside>

		<!-- Main column (mobile frame + tablet/desktop content area) -->
		<div class="flex min-h-screen flex-1 flex-col lg:min-h-0">
		<!-- Update Banner -->
		{#if updateStore.showBanner}
			<button
				onclick={() => (updateStore.sheetOpen = true)}
				class="flex w-full items-center justify-center gap-2 bg-primary px-4 py-2 text-sm font-medium text-white"
			>
				<Sync class="text-[16px]" />
				Neue Version verf&uuml;gbar &mdash; tippen zum Aktualisieren
			</button>
		{/if}
		<UpdateBanner />

		<!-- Header -->
		<header
			class="sticky top-0 z-10 flex items-center justify-between border-b border-primary/10 bg-bg-light/80 px-4 py-4 backdrop-blur-md dark:bg-bg-dark/80 lg:px-8"
		>
			<div class="flex items-center gap-3">
				<div
					class="flex size-10 items-center justify-center overflow-hidden rounded-full border border-primary/20 bg-primary/10 lg:hidden"
				>
					<Person class="text-primary" />
				</div>
				<div>
					<p class="text-xs font-medium uppercase tracking-wider text-slate-500 dark:text-slate-400">Dashboard</p>
					<h2 class="text-lg font-bold leading-tight text-slate-900 dark:text-slate-100">{pageTitle}</h2>
				</div>
			</div>
			<button
				type="button"
				onclick={() => paletteStore.show()}
				aria-label="Befehlspalette öffnen (Cmd+K)"
				class="rounded-full p-2 text-slate-600 transition-colors hover:bg-slate-100 dark:text-slate-400 dark:hover:bg-white/10 lg:hidden"
			>
				<Search />
			</button>
		</header>

		<!-- Main Content -->
		<main class="flex-1 overflow-y-auto px-4 pb-24 lg:px-8 lg:pb-8">
			{@render children()}
		</main>

		<!-- Bottom Navigation — mobile only; desktop uses the sidebar. -->
		<nav
			class="fixed bottom-0 left-0 right-0 z-20 mx-auto max-w-[768px] border-t border-primary/10 bg-bg-light/80 px-4 pb-6 pt-2 backdrop-blur-md dark:bg-bg-dark/80 lg:hidden"
		>
			<div class="flex items-center justify-between">
				<button
					type="button"
					onclick={() => paletteStore.show()}
					aria-label="Befehlspalette öffnen"
					class="flex flex-1 flex-col items-center gap-1 bg-transparent text-slate-400 transition-colors hover:text-primary"
				>
					<Search />
					<span class="text-[10px] font-bold uppercase tracking-wider">Suche</span>
				</button>
				<a
					href="/home"
					class="flex flex-1 flex-col items-center gap-1 {isActive('/home')
						? 'text-primary'
						: 'text-slate-400 hover:text-primary'} transition-colors"
				>
					<Home class={isActive('/home') ? 'active-icon' : ''} />
					<span class="text-[10px] font-bold uppercase tracking-wider">Start</span>
				</a>
				<a
					href="/drill"
					class="flex flex-1 flex-col items-center gap-1 {isActive('/drill')
						? 'text-primary'
						: 'text-slate-400 hover:text-primary'} transition-colors"
				>
					<Style class={isActive('/drill') ? 'active-icon' : ''} />
					<span class="text-[10px] font-bold uppercase tracking-wider">&Uuml;ben</span>
				</a>
				<a
					href="/more"
					class="flex flex-1 flex-col items-center gap-1 {isMoreActive()
						? 'text-primary'
						: 'text-slate-400 hover:text-primary'} transition-colors"
				>
					<Explore class={isMoreActive() ? 'active-icon' : ''} />
					<span class="text-[10px] font-bold uppercase tracking-wider">Mehr</span>
				</a>
			</div>
		</nav>
		</div>
		<!-- /main column -->
		<CharTooltip />
		<Toast />
		<CommandPalette />
		{#if devtoolsEnabled}
			<DevTools />
		{/if}

		{#if showShortcuts}
			<button
				type="button"
				aria-label="Tastenkürzel schließen"
				class="fixed inset-0 z-40 bg-black/40 backdrop-blur-sm"
				onclick={() => (showShortcuts = false)}
			></button>
			<div
				role="dialog"
				aria-modal="true"
				class="fixed left-1/2 top-1/2 z-50 w-[92%] max-w-md -translate-x-1/2 -translate-y-1/2 rounded-2xl border border-slate-100 bg-white p-6 shadow-xl dark:border-white/5 dark:bg-slate-800"
			>
				<p class="text-[11px] font-bold uppercase tracking-wider text-primary">Tastenkürzel</p>
				<h3 class="mt-1 text-lg font-bold text-slate-900 dark:text-slate-100">Navigation</h3>
				<div class="mt-4 space-y-2 text-sm">
					{#each [['⌘ K', 'Befehlspalette'], ['g h', 'Start'], ['g d', 'Üben'], ['g s', 'Statistik'], ['g w', 'Wörterbuch'], ['g p', 'Pakete'], ['g l', 'Lexikon'], ['g c', 'Zeichen'], ['g e', 'Einstellungen']] as [keys, label]}
						<div class="flex items-center justify-between">
							<span class="text-slate-600 dark:text-slate-300">{label}</span>
							<kbd class="rounded-md border border-slate-200 bg-slate-50 px-2 py-0.5 font-mono text-xs text-slate-600 dark:border-white/10 dark:bg-white/5 dark:text-slate-300">{keys}</kbd>
						</div>
					{/each}
				</div>
				<h3 class="mt-5 text-lg font-bold text-slate-900 dark:text-slate-100">Drill</h3>
				<div class="mt-3 space-y-2 text-sm">
					{#each [['1–4', 'Karte bewerten'], ['Enter', 'Antwort prüfen'], ['←', 'Vorherige Karte'], ['?', 'Diese Hilfe']] as [keys, label]}
						<div class="flex items-center justify-between">
							<span class="text-slate-600 dark:text-slate-300">{label}</span>
							<kbd class="rounded-md border border-slate-200 bg-slate-50 px-2 py-0.5 font-mono text-xs text-slate-600 dark:border-white/10 dark:bg-white/5 dark:text-slate-300">{keys}</kbd>
						</div>
					{/each}
				</div>
				<button
					onclick={() => (showShortcuts = false)}
					class="mt-5 w-full rounded-xl bg-primary px-4 py-2.5 text-sm font-bold text-white shadow-sm transition-colors hover:bg-primary/90"
				>
					Schließen
				</button>
			</div>
		{/if}

		{#if onboardingStore.showOnboarding}
			<button
				type="button"
				aria-label="Onboarding schließen"
				class="fixed inset-0 z-40 bg-black/50 backdrop-blur-sm"
				onclick={() => onboardingStore.dismiss()}
			></button>
			<div
				role="dialog"
				aria-modal="true"
				class="fixed left-1/2 top-1/2 z-50 w-[92%] max-w-md -translate-x-1/2 -translate-y-1/2 rounded-2xl border border-slate-100 bg-white p-6 shadow-xl dark:border-white/5 dark:bg-slate-800"
			>
				{#if onboardingStore.step === 0}
					<div class="flex flex-col items-center text-center">
						<div class="flex size-16 items-center justify-center rounded-2xl bg-primary/10">
							<Translate class="text-primary" style="font-size: 36px" />
						</div>
						<h3 class="mt-4 text-xl font-bold text-slate-900 dark:text-slate-100">Willkommen bei Taijobi</h3>
						<p class="mt-2 text-sm text-slate-500 dark:text-slate-400">
							Dein persönliches Vokabel-System mit Spaced Repetition für jede Sprache, der du begegnest.
						</p>
					</div>
				{:else if onboardingStore.step === 1}
					<div class="text-center">
						<div class="mx-auto flex size-16 items-center justify-center rounded-2xl bg-primary/10">
							<Style class="text-primary" style="font-size: 36px" />
						</div>
						<h3 class="mt-4 text-xl font-bold text-slate-900 dark:text-slate-100">Üben mit FSRS</h3>
						<p class="mt-2 text-sm text-slate-500 dark:text-slate-400">
							Karten erscheinen genau dann, wenn du sie wiederholen solltest. Bewerte mit 1–4, der Algorithmus plant den Rest.
						</p>
					</div>
				{:else if onboardingStore.step === 2}
					<div class="text-center">
						<div class="mx-auto flex size-16 items-center justify-center rounded-2xl bg-primary/10">
							<Inventory2 class="text-primary" style="font-size: 36px" />
						</div>
						<h3 class="mt-4 text-xl font-bold text-slate-900 dark:text-slate-100">Pakete & Lexikon</h3>
						<p class="mt-2 text-sm text-slate-500 dark:text-slate-400">
							Installiere Lehrbuch-Pakete (HSK, Lóng) oder sammle Wörter beim Lesen in dein persönliches Lexikon.
						</p>
					</div>
				{:else if onboardingStore.step === 3}
					<div class="text-center">
						<div class="mx-auto flex size-16 items-center justify-center rounded-2xl bg-primary/10">
							<Sync class="text-primary" style="font-size: 36px" />
						</div>
						<h3 class="mt-4 text-xl font-bold text-slate-900 dark:text-slate-100">Offline & Sync</h3>
						<p class="mt-2 text-sm text-slate-500 dark:text-slate-400">
							Funktioniert komplett offline. Optional: mehrere Geräte über einen Sync-Schlüssel verbinden — kein Konto nötig.
						</p>
					</div>
				{:else}
					<div>
						<div class="flex flex-col items-center text-center">
							<div class="flex size-16 items-center justify-center rounded-2xl bg-primary/10">
								<Download class="text-primary" style="font-size: 36px" />
							</div>
							<h3 class="mt-4 text-xl font-bold text-slate-900 dark:text-slate-100">Wörterbücher installieren</h3>
							<p class="mt-2 text-sm text-slate-500 dark:text-slate-400">
								Für automatische Anreicherung neuer Wörter. Du kannst das auch später unter Pakete nachholen.
							</p>
						</div>

						<div class="mt-4 space-y-2">
							{#each [
								{ key: 'zh' as const, label: 'Chinesisch', desc: 'CEDICT, Strichfolge, Zerlegung (~8 MB)', loaded: zhLoaded },
								{ key: 'en' as const, label: 'Englisch', desc: 'Wiktionary (~19 MB)', loaded: enLoaded },
								{ key: 'de' as const, label: 'Deutsch', desc: 'Wiktionary (~5 MB)', loaded: deLoaded },
							] as opt (opt.key)}
								<div class="rounded-xl border border-slate-100 bg-slate-50/50 p-3 dark:border-white/5 dark:bg-white/5">
									<div class="flex items-center justify-between gap-3">
										<div class="min-w-0 flex-1">
											<p class="text-sm font-medium text-slate-700 dark:text-slate-200">{opt.label}</p>
											<p class="truncate text-xs text-slate-400 dark:text-slate-500">{opt.desc}</p>
										</div>
										{#if opt.loaded}
											<span class="rounded-md bg-green-100 px-2 py-1 text-[10px] font-bold uppercase tracking-wider text-green-700 dark:bg-green-500/20 dark:text-green-400">Geladen</span>
										{:else if downloadStore.active === opt.key}
											<span class="text-xs text-primary">
												{#if downloadStore.total > 0}
													{Math.round((downloadStore.progress / downloadStore.total) * 100)}%
												{:else}
													…
												{/if}
											</span>
										{:else}
											<button
												onclick={() => downloadStore.start(opt.key)}
												disabled={downloadStore.active !== null}
												class="flex items-center gap-1 rounded-lg bg-primary/10 px-3 py-1.5 text-xs font-bold text-primary transition-colors hover:bg-primary/20 disabled:opacity-50"
											>
												<Download style="font-size: 14px" />
												Installieren
											</button>
										{/if}
									</div>
									{#if downloadStore.active === opt.key && downloadStore.total > 0}
										<div class="mt-2 h-1.5 w-full overflow-hidden rounded-full bg-slate-100 dark:bg-white/10">
											<div
												class="h-full rounded-full bg-primary transition-all duration-200"
												style="width: {Math.round((downloadStore.progress / downloadStore.total) * 100)}%"
											></div>
										</div>
									{/if}
								</div>
							{/each}
						</div>
					</div>
				{/if}

				<div class="mt-5 flex items-center justify-center gap-1.5">
					{#each [0, 1, 2, 3, 4] as i}
						<div class="size-1.5 rounded-full {i === onboardingStore.step ? 'bg-primary' : 'bg-slate-200 dark:bg-white/10'}"></div>
					{/each}
				</div>

				<div class="mt-5 flex gap-2">
					<button
						onclick={() => onboardingStore.dismiss()}
						disabled={downloadStore.active !== null}
						class="flex-1 rounded-xl border border-slate-200 px-4 py-2.5 text-sm font-medium text-slate-600 transition-colors hover:bg-slate-50 disabled:opacity-50 dark:border-white/10 dark:text-slate-300 dark:hover:bg-white/5"
					>
						Überspringen
					</button>
					<button
						onclick={() => onboardingStore.next()}
						disabled={downloadStore.active !== null}
						class="flex-1 rounded-xl bg-primary px-4 py-2.5 text-sm font-bold text-white shadow-sm transition-colors hover:bg-primary/90 disabled:opacity-50"
					>
						{onboardingStore.step === 4 ? 'Loslegen' : 'Weiter'}
					</button>
				</div>
			</div>
		{/if}
	</div>
{/if}
