<script lang="ts">
	import ContentCopy from '$lib/icons/ContentCopy.svelte';
	import Download from '$lib/icons/Download.svelte';
	import Sync from '$lib/icons/Sync.svelte';
	import VpnKey from '$lib/icons/VpnKey.svelte';
	import Icon from '$lib/icons/Icon.svelte';
	import {
		getSyncKey,
		setSyncKey,
		clearSyncKey,
		isSyncEnabled,
		connectSync,
		disconnectSync,
		syncFull,
		getLastSyncTimestamp,
	} from '$lib/sync';
	import { syncWS } from '$lib/sync-ws.svelte';
	import { toastStore } from '$lib/toast.svelte';
	import { themeStore, type Theme } from '$lib/theme.svelte';
	import { data } from '$lib/data.svelte';
	import { downloadStore } from '$lib/download-state.svelte';

	const themeOptions: { value: Theme; label: string; icon: string }[] = [
		{ value: 'light', label: 'Hell', icon: 'light_mode' },
		{ value: 'dark', label: 'Dunkel', icon: 'dark_mode' },
		{ value: 'system', label: 'System', icon: 'contrast' },
	];

	let syncKey = $state(getSyncKey() ?? '');
	let enabled = $state(isSyncEnabled());
	let inputKey = $state('');
	let syncing = $state(false);
	let lastSync = $state(getLastSyncTimestamp());

	function generateKey(): void {
		const bytes = new Uint8Array(24);
		crypto.getRandomValues(bytes);
		const key = Array.from(bytes)
			.map((b) => b.toString(36).padStart(2, '0'))
			.join('')
			.slice(0, 32);
		syncKey = key;
		setSyncKey(key);
		enabled = true;
		connectSync();
		toastStore.show('Sync-Schlüssel generiert');
	}

	function linkKey(): void {
		const key = inputKey.trim();
		if (!key) return;
		syncKey = key;
		setSyncKey(key);
		enabled = true;
		inputKey = '';
		connectSync();
		toastStore.show('Sync-Schlüssel verknüpft');
	}

	function disconnect(): void {
		clearSyncKey();
		syncKey = '';
		enabled = false;
		toastStore.show('Sync getrennt');
	}

	async function manualSync(): Promise<void> {
		if (!syncKey || syncing) return;
		syncing = true;
		try {
			const result = await syncFull(syncKey);
			lastSync = Date.now();
			toastStore.show(`Sync: ${result.pushed} gepusht, ${result.pulled} gezogen`);
		} catch (e) {
			toastStore.show(`Sync fehlgeschlagen: ${e instanceof Error ? e.message : 'Fehler'}`);
		} finally {
			syncing = false;
		}
	}

	async function copyKey(): Promise<void> {
		if (!syncKey) return;
		await navigator.clipboard.writeText(syncKey);
		toastStore.show('Schlüssel kopiert');
	}

	function maskedKey(key: string): string {
		if (key.length <= 8) return key;
		return key.slice(0, 4) + '\u2022'.repeat(key.length - 8) + key.slice(-4);
	}

	function formatTimestamp(ts: number): string {
		if (ts === 0) return 'Noch nie';
		return new Date(ts).toLocaleString('de-DE', {
			day: '2-digit',
			month: '2-digit',
			year: 'numeric',
			hour: '2-digit',
			minute: '2-digit',
		});
	}

	// Dictionary load state + active download (shared across pages via downloadStore)
	let chineseLoaded = $derived(data.chineseDataLoaded());
	let enLoaded = $derived(data.endictLoaded());
	let deLoaded = $derived(data.dedictLoaded());
</script>

<div class="space-y-6 py-4">
	<!-- Theme -->
	<div>
		<p class="text-[11px] font-bold uppercase tracking-wider text-primary">Erscheinungsbild</p>
		<p class="mt-1 text-sm text-slate-500 dark:text-slate-400">
			Wähle dein bevorzugtes Design.
		</p>
	</div>
	<div class="grid grid-cols-3 gap-2">
		{#each themeOptions as opt (opt.value)}
			<button
				onclick={() => themeStore.set(opt.value)}
				class="flex flex-col items-center gap-1.5 rounded-xl border px-3 py-3 text-sm font-medium transition-colors {themeStore.theme === opt.value
					? 'border-primary bg-primary/10 text-primary'
					: 'border-slate-100 bg-white text-slate-600 hover:bg-slate-50 dark:border-white/5 dark:bg-white/5 dark:text-slate-300 dark:hover:bg-white/10'}"
			>
				<Icon name={opt.icon} class="text-xl" />
				{opt.label}
			</button>
		{/each}
	</div>

	<!-- Chinese Data -->
	<div>
		<p class="text-[11px] font-bold uppercase tracking-wider text-primary">Chinesische Daten</p>
		<p class="mt-1 text-sm text-slate-500 dark:text-slate-400">
			Wörterbuch, Strichfolge und Zerlegung (~8 MB komprimiert).
		</p>
	</div>
	<div class="rounded-2xl border border-slate-100 bg-white p-4 shadow-sm dark:border-white/5 dark:bg-white/5">
		{#if chineseLoaded}
			<div class="flex items-center gap-2">
				<div class="size-2.5 rounded-full bg-green-500"></div>
				<span class="text-sm font-medium text-slate-700 dark:text-slate-200">Geladen</span>
			</div>
			<p class="mt-2 text-xs text-slate-400 dark:text-slate-500">
				CC-CEDICT, Strichfolge und Zerlegungsdaten sind verfügbar.
			</p>
		{:else if downloadStore.active === 'zh'}
			<div class="flex items-center gap-2">
				<Sync class="animate-spin text-[18px] text-primary" />
				<span class="text-sm font-medium text-slate-700 dark:text-slate-200">Herunterladen…</span>
			</div>
			{#if downloadStore.total > 0}
				<div class="mt-3 h-2 w-full overflow-hidden rounded-full bg-slate-100 dark:bg-white/10">
					<div
						class="h-full rounded-full bg-primary transition-all duration-300"
						style="width: {Math.round((downloadStore.progress / downloadStore.total) * 100)}%"
					></div>
				</div>
				<p class="mt-1 text-xs text-slate-400 dark:text-slate-500">
					{Math.round(downloadStore.progress / 1024 / 1024)} / {Math.round(downloadStore.total / 1024 / 1024)} MB
				</p>
			{/if}
		{:else}
			<div class="flex items-center gap-2">
				<div class="size-2.5 rounded-full bg-slate-300 dark:bg-slate-600"></div>
				<span class="text-sm font-medium text-slate-700 dark:text-slate-200">Nicht geladen</span>
			</div>
			<p class="mt-2 text-xs text-slate-400 dark:text-slate-500">
				Für Zeichenzerlegung, Strichfolge und CEDICT-Suche.
			</p>
			<button
				onclick={() => downloadStore.start('zh')}
				disabled={downloadStore.active !== null}
				class="mt-3 flex w-full items-center justify-center gap-2 rounded-xl bg-primary px-4 py-2.5 text-sm font-bold text-white shadow-sm transition-colors hover:bg-primary/90 disabled:opacity-50"
			>
				<Download class="text-[18px]" />
				Herunterladen
			</button>
		{/if}
	</div>

	<!-- EN/DE Dictionaries -->
	<div>
		<p class="text-[11px] font-bold uppercase tracking-wider text-primary">W&ouml;rterb&uuml;cher</p>
		<p class="mt-1 text-sm text-slate-500 dark:text-slate-400">
			Definitionen f&uuml;r Englisch und Deutsch (Wiktionary).
		</p>
	</div>
	<div class="space-y-3">
		<!-- English -->
		<div class="rounded-2xl border border-slate-100 bg-white p-4 shadow-sm dark:border-white/5 dark:bg-white/5">
			<div class="flex items-center justify-between">
				<div class="flex items-center gap-2">
					{#if enLoaded}
						<div class="size-2.5 rounded-full bg-green-500"></div>
					{:else}
						<div class="size-2.5 rounded-full bg-slate-300 dark:bg-slate-600"></div>
					{/if}
					<span class="text-sm font-medium text-slate-700 dark:text-slate-200">English</span>
				</div>
				{#if enLoaded}
					<span class="text-xs text-slate-400 dark:text-slate-500">Geladen</span>
				{:else if downloadStore.active === 'en'}
					<span class="text-xs text-primary">
						{#if downloadStore.total > 0}
							{Math.round(downloadStore.progress / 1024 / 1024)} / {Math.round(downloadStore.total / 1024 / 1024)} MB
						{:else}
							Herunterladen&hellip;
						{/if}
					</span>
				{:else}
					<button
						onclick={() => downloadStore.start('en')}
						disabled={downloadStore.active !== null}
						class="flex items-center gap-1 rounded-lg bg-primary/10 px-3 py-1.5 text-xs font-bold text-primary transition-colors hover:bg-primary/20 disabled:opacity-50"
					>
						<Download class="text-[14px]" />
						Installieren
					</button>
				{/if}
			</div>
			{#if downloadStore.active === 'en' && downloadStore.total > 0}
				<div class="mt-2 h-1.5 w-full overflow-hidden rounded-full bg-slate-100 dark:bg-white/10">
					<div
						class="h-full rounded-full bg-primary transition-all duration-300"
						style="width: {Math.round((downloadStore.progress / downloadStore.total) * 100)}%"
					></div>
				</div>
			{/if}
		</div>

		<!-- German -->
		<div class="rounded-2xl border border-slate-100 bg-white p-4 shadow-sm dark:border-white/5 dark:bg-white/5">
			<div class="flex items-center justify-between">
				<div class="flex items-center gap-2">
					{#if deLoaded}
						<div class="size-2.5 rounded-full bg-green-500"></div>
					{:else}
						<div class="size-2.5 rounded-full bg-slate-300 dark:bg-slate-600"></div>
					{/if}
					<span class="text-sm font-medium text-slate-700 dark:text-slate-200">Deutsch</span>
				</div>
				{#if deLoaded}
					<span class="text-xs text-slate-400 dark:text-slate-500">Geladen</span>
				{:else if downloadStore.active === 'de'}
					<span class="text-xs text-primary">
						{#if downloadStore.total > 0}
							{Math.round(downloadStore.progress / 1024 / 1024)} / {Math.round(downloadStore.total / 1024 / 1024)} MB
						{:else}
							Herunterladen&hellip;
						{/if}
					</span>
				{:else}
					<button
						onclick={() => downloadStore.start('de')}
						disabled={downloadStore.active !== null}
						class="flex items-center gap-1 rounded-lg bg-primary/10 px-3 py-1.5 text-xs font-bold text-primary transition-colors hover:bg-primary/20 disabled:opacity-50"
					>
						<Download class="text-[14px]" />
						Installieren
					</button>
				{/if}
			</div>
			{#if downloadStore.active === 'de' && downloadStore.total > 0}
				<div class="mt-2 h-1.5 w-full overflow-hidden rounded-full bg-slate-100 dark:bg-white/10">
					<div
						class="h-full rounded-full bg-primary transition-all duration-300"
						style="width: {Math.round((downloadStore.progress / downloadStore.total) * 100)}%"
					></div>
				</div>
			{/if}
		</div>
	</div>

	<!-- Sync -->
	<div>
		<p class="text-[11px] font-bold uppercase tracking-wider text-primary">Sync</p>
		<p class="mt-1 text-sm text-slate-500 dark:text-slate-400">
			Mehrere Geräte synchronisieren. Kein Konto nötig.
		</p>
	</div>

	{#if enabled}
		<!-- Connected state -->
		<div class="rounded-2xl border border-slate-100 bg-white p-4 shadow-sm dark:border-white/5 dark:bg-white/5">
			<div class="flex items-center gap-2">
				<div
					class="size-2.5 rounded-full {syncWS.connected ? 'bg-green-500' : 'bg-amber-500'}"
				></div>
				<span class="text-sm font-medium text-slate-700 dark:text-slate-200">
					{syncWS.connected ? 'Verbunden' : 'Verbindung wird hergestellt…'}
				</span>
			</div>

			<div class="mt-3 flex items-center gap-2">
				<code class="flex-1 rounded-lg bg-slate-50 px-3 py-2 text-xs text-slate-600 dark:bg-white/5 dark:text-slate-400">
					{maskedKey(syncKey)}
				</code>
				<button
					onclick={copyKey}
					class="rounded-lg bg-slate-100 p-2 text-slate-500 transition-colors hover:bg-slate-200 dark:bg-white/10 dark:text-slate-400 dark:hover:bg-white/15"
				>
					<ContentCopy class="text-[18px]" />
				</button>
			</div>

			<p class="mt-2 text-xs text-slate-400 dark:text-slate-500">
				Letzte Synchronisierung: {formatTimestamp(lastSync)}
			</p>

			<div class="mt-4 flex gap-2">
				<button
					onclick={manualSync}
					disabled={syncing}
					class="flex flex-1 items-center justify-center gap-2 rounded-xl bg-primary px-4 py-2.5 text-sm font-bold text-white shadow-sm transition-colors hover:bg-primary/90 disabled:opacity-50"
				>
					<Sync class="text-[18px] {syncing ? 'animate-spin' : ''}" />
					{syncing ? 'Synchronisiere…' : 'Sync jetzt'}
				</button>
				<button
					onclick={disconnect}
					class="rounded-xl border border-red-200 px-4 py-2.5 text-sm font-medium text-red-600 transition-colors hover:bg-red-50"
				>
					Trennen
				</button>
			</div>
		</div>

		<!-- Link to another device -->
		<div class="rounded-2xl border border-slate-100 bg-white p-4 shadow-sm dark:border-white/5 dark:bg-white/5">
			<p class="text-sm font-medium text-slate-700 dark:text-slate-200">Auf anderem Gerät einrichten</p>
			<p class="mt-1 text-xs text-slate-400 dark:text-slate-500">
				Kopiere den Schlüssel und füge ihn auf dem anderen Gerät ein.
			</p>
		</div>
	{:else}
		<!-- Not connected state -->
		<div class="rounded-2xl border border-slate-100 bg-white p-4 shadow-sm dark:border-white/5 dark:bg-white/5">
			<p class="text-sm font-medium text-slate-700 dark:text-slate-200">Neuen Sync starten</p>
			<p class="mt-1 text-xs text-slate-400 dark:text-slate-500">
				Erstelle einen Schlüssel für dieses Gerät.
			</p>
			<button
				onclick={generateKey}
				class="mt-3 flex w-full items-center justify-center gap-2 rounded-xl bg-primary px-4 py-2.5 text-sm font-bold text-white shadow-sm transition-colors hover:bg-primary/90"
			>
				<VpnKey class="text-[18px]" />
				Schlüssel generieren
			</button>
		</div>

		<div class="rounded-2xl border border-slate-100 bg-white p-4 shadow-sm dark:border-white/5 dark:bg-white/5">
			<p class="text-sm font-medium text-slate-700 dark:text-slate-200">Vorhandenen Schlüssel eingeben</p>
			<p class="mt-1 text-xs text-slate-400 dark:text-slate-500">
				Wenn du bereits einen Schlüssel auf einem anderen Gerät hast.
			</p>
			<div class="mt-3 flex gap-2">
				<input
					type="text"
					bind:value={inputKey}
					placeholder="Sync-Schlüssel einfügen"
					class="flex-1 rounded-xl border border-slate-200 bg-slate-50 px-3 py-2.5 text-sm text-slate-700 placeholder:text-slate-300 focus:border-primary focus:outline-none dark:border-white/10 dark:bg-white/5 dark:text-slate-200 dark:placeholder:text-slate-600"
				/>
				<button
					onclick={linkKey}
					disabled={!inputKey.trim()}
					class="rounded-xl bg-primary px-4 py-2.5 text-sm font-bold text-white shadow-sm transition-colors hover:bg-primary/90 disabled:opacity-50"
				>
					Verknüpfen
				</button>
			</div>
		</div>
	{/if}

	<!-- About link -->
	<a
		href="/about"
		class="flex items-center justify-between rounded-2xl border border-slate-100 bg-white p-4 shadow-sm transition-colors hover:bg-slate-50 dark:border-white/5 dark:bg-white/5 dark:hover:bg-white/10"
	>
		<div>
			<p class="text-sm font-medium text-slate-700 dark:text-slate-200">Über Taijobi</p>
			<p class="mt-0.5 text-xs text-slate-400 dark:text-slate-500">FAQ, Datenschutz, Tech Stack</p>
		</div>
		<svg class="size-4 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
			<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
		</svg>
	</a>
</div>
