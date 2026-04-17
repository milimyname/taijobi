<script lang="ts">
	import {
		getWasmMemoryBytes,
		getWasmDbSize,
		getBuildId,
		getPacks,
		getDrillStats,
		close,
		queryRaw,
		type Pack,
		type QueryResult,
	} from '$lib/wasm';
	import { syncWS } from '$lib/sync-ws.svelte';
	import { getSyncKey, clearSyncKey, getLastSyncTimestamp } from '$lib/sync';
	import { clearCache as clearChineseCache } from '$lib/dictionary-data';
	import { featureStore } from '$lib/features.svelte';
	import { devtoolsStore } from '$lib/devtools-store.svelte';
	import { LS_SQL_HISTORY } from '$lib/config';

	const TABS = ['info', 'wasm', 'sync', 'data', 'flags', 'sql'] as const;
	const TAB_LABELS: Record<(typeof TABS)[number], string> = {
		info: 'Info',
		wasm: 'WASM',
		sync: 'Sync',
		data: 'Data',
		flags: 'Flags',
		sql: 'SQL',
	};

	let open = $state(false);
	let activeTab = $state<(typeof TABS)[number]>('info');

	// Info tab
	let memoryBytes = $state(0);
	let dbSizeBytes = $state(0);
	let buildId = $state('');
	let packs: Pack[] = $state([]);
	let cardCount = $state(0);
	let lexiconCount = $state(0);

	function refresh() {
		memoryBytes = getWasmMemoryBytes();
		dbSizeBytes = getWasmDbSize();
		buildId = getBuildId();
		packs = getPacks();
		const stats = getDrillStats();
		cardCount = stats.total_cards;
		lexiconCount = stats.lexicon_count;
	}

	function toggle() {
		open = !open;
		if (open) refresh();
	}

	function formatBytes(bytes: number): string {
		if (bytes < 1024) return `${bytes} B`;
		if (bytes < 1048576) return `${(bytes / 1024).toFixed(1)} KB`;
		return `${(bytes / 1048576).toFixed(1)} MB`;
	}

	function relativeTime(ts: number): string {
		if (ts === 0) return 'nie';
		const diff = Math.floor((Date.now() - ts) / 1000);
		if (diff < 1) return 'jetzt';
		if (diff < 60) return `${diff}s`;
		if (diff < 3600) return `${Math.floor(diff / 60)}m`;
		return `${Math.floor(diff / 3600)}h`;
	}

	// OPFS browser
	interface OpfsFile {
		name: string;
		size: number;
	}
	let opfsFiles = $state<OpfsFile[]>([]);
	let opfsLoading = $state(false);

	async function refreshOpfs() {
		opfsLoading = true;
		try {
			const root = await navigator.storage.getDirectory();
			const files: OpfsFile[] = [];
			for await (const [name, handle] of (root as any).entries()) {
				if (handle.kind === 'file') {
					const file = await (handle as FileSystemFileHandle).getFile();
					files.push({ name, size: file.size });
				} else {
					files.push({ name: name + '/', size: -1 });
				}
			}
			files.sort((a, b) => a.name.localeCompare(b.name));
			opfsFiles = files;
		} catch {
			opfsFiles = [];
		} finally {
			opfsLoading = false;
		}
	}

	async function downloadOpfsFile(name: string) {
		try {
			const root = await navigator.storage.getDirectory();
			const fh = await root.getFileHandle(name);
			const file = await fh.getFile();
			const url = URL.createObjectURL(file);
			const a = document.createElement('a');
			a.href = url;
			a.download = name;
			a.click();
			URL.revokeObjectURL(url);
		} catch (e) {
			console.error('[DevTools] OPFS download failed:', e);
		}
	}

	async function deleteOpfsFile(name: string) {
		try {
			const root = await navigator.storage.getDirectory();
			await root.removeEntry(name);
			await refreshOpfs();
		} catch (e) {
			console.error('[DevTools] OPFS delete failed:', e);
		}
	}

	// localStorage inspector
	interface LsEntry {
		key: string;
		value: string;
		size: number;
	}
	let lsEntries = $state<LsEntry[]>([]);

	function refreshLs() {
		const entries: LsEntry[] = [];
		for (let i = 0; i < localStorage.length; i++) {
			const key = localStorage.key(i);
			if (!key) continue;
			const value = localStorage.getItem(key) ?? '';
			entries.push({ key, value, size: new Blob([value]).size });
		}
		entries.sort((a, b) => a.key.localeCompare(b.key));
		lsEntries = entries;
	}

	function deleteLsKey(key: string) {
		localStorage.removeItem(key);
		refreshLs();
	}

	$effect(() => {
		if (open && activeTab === 'data') {
			refreshOpfs();
			refreshLs();
		}
	});

	// Flags tab
	let flagKeys = $derived(Object.keys(featureStore.enabled).toSorted());

	// SQL tab
	let sqlQuery = $state('');
	let sqlResult = $state<QueryResult | null>(null);
	let sqlError = $state('');
	let sqlHistory = $state<string[]>(loadSqlHistory());
	const SQL_HISTORY_MAX = 20;

	function loadSqlHistory(): string[] {
		try {
			const raw = localStorage.getItem(LS_SQL_HISTORY);
			if (!raw) return [];
			const parsed = JSON.parse(raw);
			if (!Array.isArray(parsed)) return [];
			return parsed.filter((x) => typeof x === 'string').slice(0, SQL_HISTORY_MAX);
		} catch {
			return [];
		}
	}

	function saveSqlHistory(q: string) {
		const next = [q, ...sqlHistory.filter((h) => h !== q)].slice(0, SQL_HISTORY_MAX);
		sqlHistory = next;
		try {
			localStorage.setItem(LS_SQL_HISTORY, JSON.stringify(next));
		} catch {
			/* ignore quota */
		}
	}

	function runQuery() {
		const q = sqlQuery.trim();
		if (!q) return;
		sqlError = '';
		try {
			sqlResult = queryRaw(q);
			saveSqlHistory(q);
		} catch (e) {
			sqlError = e instanceof Error ? e.message : String(e);
			sqlResult = null;
		}
	}

	function runSchema() {
		sqlQuery = "SELECT name, sql FROM sqlite_master WHERE type='table' ORDER BY name";
		runQuery();
	}

	function clearSql() {
		sqlQuery = '';
		sqlResult = null;
		sqlError = '';
	}

	function restoreHistory(q: string) {
		sqlQuery = q;
	}

	function stringifyCell(v: string | number | null): string {
		if (v === null) return '';
		return typeof v === 'string' ? v : String(v);
	}

	/** Escape a cell for TSV — replace tabs/newlines/CR so each row is one line
	 *  and each column is one tab-delimited field. */
	function tsvCell(v: string | number | null): string {
		if (v === null) return '';
		const s = typeof v === 'string' ? v : String(v);
		return s.replace(/\t/g, ' ').replace(/\r?\n/g, ' ');
	}

	function exportResultTsv() {
		if (!sqlResult) return;
		const lines = [sqlResult.columns.join('\t')];
		for (const row of sqlResult.rows) lines.push(row.map(tsvCell).join('\t'));
		const blob = new Blob([lines.join('\n')], { type: 'text/tab-separated-values' });
		const url = URL.createObjectURL(blob);
		const a = document.createElement('a');
		a.href = url;
		a.download = `taijobi-query-${Date.now()}.tsv`;
		a.click();
		URL.revokeObjectURL(url);
	}

	// Danger zone
	let confirmAction = $state<string | null>(null);

	async function clearOpfs() {
		try {
			close();
			const root = await navigator.storage.getDirectory();
			await root.removeEntry('taijobi.db').catch(() => {});
			await root.removeEntry('dictionary-data', { recursive: true }).catch(() => {});
			// Also clean up legacy directory name
			await root.removeEntry('chinese-data', { recursive: true }).catch(() => {});
		} catch {
			/* ignore */
		}
		window.location.reload();
	}

	function clearLocalStorage() {
		localStorage.clear();
		window.location.reload();
	}

	async function fullReset() {
		try {
			close();
			const root = await navigator.storage.getDirectory();
			await root.removeEntry('taijobi.db').catch(() => {});
			await root.removeEntry('dictionary-data', { recursive: true }).catch(() => {});
			// Also clean up legacy directory name
			await root.removeEntry('chinese-data', { recursive: true }).catch(() => {});
		} catch {
			/* ignore */
		}
		clearSyncKey();
		localStorage.clear();
		window.location.reload();
	}
</script>

<!-- Toggle button -->
<button
	onclick={toggle}
	class="fixed bottom-20 left-3 z-50 flex size-8 items-center justify-center rounded-full bg-slate-800 text-xs font-bold text-white opacity-30 transition-opacity hover:opacity-100"
	aria-label="DevTools"
>
	{open ? 'x' : 'D'}
</button>

{#if open}
	<div
		class="fixed bottom-28 left-3 right-3 z-50 flex max-h-[60vh] flex-col overflow-hidden rounded-2xl border border-slate-200 dark:border-white/10 bg-white shadow-lg dark:bg-slate-900 sm:left-auto sm:right-3 sm:w-80"
	>
		<!-- Header -->
		<div class="flex items-center justify-between border-b border-slate-100 dark:border-white/5 px-4 py-2.5">
			<span class="text-xs font-bold tracking-wide text-slate-900 dark:text-slate-100">DevTools</span>
			<button
				onclick={() => {
					open = false;
				}}
				class="cursor-pointer text-xs text-slate-400 hover:text-slate-700 dark:text-slate-200"
			>
				close
			</button>
		</div>

		<!-- Tabs -->
		<div class="flex border-b border-slate-100 dark:border-white/5">
			{#each TABS as tab}
				<button
					onclick={() => {
						activeTab = tab;
						if (tab === 'info') refresh();
					}}
					class="flex-1 cursor-pointer py-2 text-[11px] font-semibold transition-colors {activeTab === tab ? 'border-b-2 border-primary bg-primary/10 text-slate-900 dark:text-slate-100' : 'text-slate-400 hover:text-slate-700 dark:text-slate-200'}"
				>
					{TAB_LABELS[tab]}
				</button>
			{/each}
		</div>

		<!-- Content -->
		<div class="min-h-0 flex-1 overflow-y-auto">
			{#if activeTab === 'info'}
				<div class="space-y-3 p-3">
					<!-- Build -->
					<div class="rounded-lg bg-slate-50 px-3 py-2">
						<div class="text-[9px] font-bold uppercase tracking-wider text-slate-400">
							Build
						</div>
						<div class="mt-0.5 font-mono text-xs text-slate-700 dark:text-slate-200">{buildId}</div>
					</div>

					<!-- Memory -->
					<div class="grid grid-cols-2 gap-2">
						<div class="rounded-lg bg-slate-50 px-3 py-2 text-center">
							<div class="text-sm font-bold text-slate-900 dark:text-slate-100">{formatBytes(memoryBytes)}</div>
							<div class="text-[9px] text-slate-400">WASM Memory</div>
						</div>
						<div class="rounded-lg bg-slate-50 px-3 py-2 text-center">
							<div class="text-sm font-bold text-slate-900 dark:text-slate-100">{formatBytes(dbSizeBytes)}</div>
							<div class="text-[9px] text-slate-400">SQLite DB</div>
						</div>
					</div>

					<!-- Data counts -->
					<div class="grid grid-cols-2 gap-2">
						<div class="rounded-lg bg-slate-50 px-3 py-2 text-center">
							<div class="text-sm font-bold text-slate-900 dark:text-slate-100">{cardCount}</div>
							<div class="text-[9px] text-slate-400">Karten</div>
						</div>
						<div class="rounded-lg bg-slate-50 px-3 py-2 text-center">
							<div class="text-sm font-bold text-slate-900 dark:text-slate-100">{lexiconCount}</div>
							<div class="text-[9px] text-slate-400">Lexikon</div>
						</div>
					</div>

					<!-- Packs -->
					{#if packs.length > 0}
						<div>
							<div class="mb-1 text-[9px] font-bold uppercase tracking-wider text-slate-400">
								Packs ({packs.length})
							</div>
							{#each packs as pack}
								<div class="flex items-center justify-between py-0.5 text-xs">
									<span class="truncate text-slate-700 dark:text-slate-200">{pack.name}</span>
									<span class="shrink-0 text-slate-400">{pack.word_count}</span>
								</div>
							{/each}
						</div>
					{/if}

					<button
						onclick={refresh}
						class="w-full cursor-pointer rounded-lg bg-primary/10 px-3 py-1.5 text-center text-[10px] font-bold text-primary hover:bg-primary/20"
					>
						Refresh
					</button>
				</div>
			{:else if activeTab === 'wasm'}
				<div class="space-y-3 p-3">
					<!-- Stats row -->
					<div class="grid grid-cols-3 gap-2">
						<div class="rounded-lg bg-slate-50 px-3 py-2 text-center dark:bg-white/5">
							<div class="text-sm font-bold text-slate-900 dark:text-slate-100">
								{devtoolsStore.callCount}
							</div>
							<div class="text-[9px] text-slate-400">Calls</div>
						</div>
						<div class="rounded-lg bg-slate-50 px-3 py-2 text-center dark:bg-white/5">
							<div class="text-sm font-bold text-slate-900 dark:text-slate-100">
								{devtoolsStore.avgMs.toFixed(1)}ms
							</div>
							<div class="text-[9px] text-slate-400">Avg</div>
						</div>
						<div class="rounded-lg bg-slate-50 px-3 py-2 text-center dark:bg-white/5">
							<div class="truncate text-sm font-bold text-slate-900 dark:text-slate-100">
								{devtoolsStore.slowest?.name ?? '—'}
							</div>
							<div class="text-[9px] text-slate-400">
								Slowest{#if devtoolsStore.slowest}
									({devtoolsStore.slowest.durationMs.toFixed(1)}ms)
								{/if}
							</div>
						</div>
					</div>

					<!-- Call log -->
					<div>
						<div class="mb-2 flex items-center justify-between">
							<span class="text-[11px] font-semibold text-slate-900 dark:text-slate-100">Recent calls</span>
							<button
								onclick={() => devtoolsStore.clear()}
								class="cursor-pointer rounded px-1.5 py-0.5 text-[10px] font-medium text-slate-400 transition-colors hover:bg-slate-100 hover:text-slate-700 dark:hover:bg-white/10 dark:hover:text-slate-200"
							>
								clear
							</button>
						</div>
						{#if devtoolsStore.entries.length === 0}
							<div class="py-3 text-center text-xs text-slate-400">No calls yet</div>
						{:else}
							<div
								class="divide-y divide-slate-100 overflow-hidden rounded-xl border border-slate-200 dark:divide-white/5 dark:border-white/10"
							>
								{#each devtoolsStore.recent(20) as entry (entry.id)}
									<div
										class="flex items-center justify-between bg-white px-2.5 py-1.5 dark:bg-white/5"
									>
										<div class="min-w-0 flex-1">
											<span class="font-mono text-[11px] font-medium text-slate-700 dark:text-slate-200">
												{entry.name}
											</span>
										</div>
										<div class="flex shrink-0 items-center gap-2">
											<span
												class="font-mono text-[10px] {entry.durationMs > 5
													? 'font-bold text-amber-600 dark:text-amber-400'
													: 'text-slate-400'}"
											>
												{entry.durationMs.toFixed(1)}ms
											</span>
											<span class="text-[8px] text-slate-300 dark:text-slate-600">
												{new Date(entry.timestamp).toLocaleTimeString('de-DE', {
													hour: '2-digit',
													minute: '2-digit',
													second: '2-digit',
												})}
											</span>
										</div>
									</div>
								{/each}
							</div>
						{/if}
					</div>
				</div>
			{:else if activeTab === 'sync'}
				<div class="space-y-3 p-3">
					<!-- WS Status -->
					<div class="flex items-center gap-2">
						{#if !getSyncKey()}
							<span class="size-2 rounded-full bg-gray-400"></span>
							<span class="text-[11px] font-semibold text-gray-500">Kein Sync-Schlüssel</span>
						{:else if syncWS.connected}
							<span class="size-2 rounded-full bg-green-500"></span>
							<span class="text-[11px] font-semibold text-green-700">Verbunden</span>
						{:else}
							<span class="size-2 rounded-full bg-red-400"></span>
							<span class="text-[11px] font-semibold text-red-600">Getrennt</span>
						{/if}
					</div>

					<!-- Sync key info -->
					{#if getSyncKey()}
						<div class="rounded-lg bg-slate-50 px-3 py-2">
							<div class="text-[9px] font-bold uppercase tracking-wider text-slate-400">
								Sync-Schlüssel
							</div>
							<div class="mt-0.5 font-mono text-[10px] text-slate-600">
								{getSyncKey()?.slice(0, 8)}…
							</div>
						</div>
					{/if}

					<!-- Last sync -->
					<div class="rounded-lg bg-slate-50 px-3 py-2">
						<div class="text-[9px] font-bold uppercase tracking-wider text-slate-400">
							Letzte Sync
						</div>
						<div class="mt-0.5 text-xs text-slate-700 dark:text-slate-200">
							{relativeTime(getLastSyncTimestamp())}
						</div>
					</div>
				</div>
			{:else if activeTab === 'data'}
				<div class="space-y-4 p-3">
					<!-- OPFS Files -->
					<div>
						<div class="mb-2 flex items-center justify-between">
							<span class="text-[11px] font-semibold text-slate-900 dark:text-slate-100">OPFS</span>
							<button
								onclick={refreshOpfs}
								class="cursor-pointer rounded px-1.5 py-0.5 text-[10px] font-medium text-slate-400 transition-colors hover:bg-slate-100 dark:hover:bg-white/10 hover:text-slate-700 dark:text-slate-200"
							>
								refresh
							</button>
						</div>
						{#if opfsLoading}
							<div class="py-3 text-center text-xs text-slate-400">Laden…</div>
						{:else if opfsFiles.length === 0}
							<div class="py-3 text-center text-xs text-slate-400">Keine Dateien</div>
						{:else}
							<div
								class="divide-y divide-slate-100 overflow-hidden rounded-xl border border-slate-200 dark:border-white/10"
							>
								{#each opfsFiles as file}
									<div
										class="flex items-center justify-between gap-1.5 bg-white px-2.5 py-1.5 dark:bg-white/5"
									>
										<div class="flex min-w-0 items-center gap-2">
											<span class="truncate font-mono text-[11px] font-medium text-slate-700 dark:text-slate-200"
												>{file.name}</span
											>
											{#if file.size >= 0}
												<span class="shrink-0 text-[9px] text-slate-400">
													{formatBytes(file.size)}
												</span>
											{/if}
										</div>
										{#if file.size >= 0}
											<div class="flex shrink-0 items-center gap-1">
												<button
													onclick={() => downloadOpfsFile(file.name)}
													class="cursor-pointer px-1 text-[9px] text-slate-400 hover:text-slate-700 dark:text-slate-200"
												>
													dl
												</button>
												<button
													onclick={() => deleteOpfsFile(file.name)}
													class="cursor-pointer px-1 text-[9px] text-red-400 hover:text-red-600"
												>
													del
												</button>
											</div>
										{/if}
									</div>
								{/each}
							</div>
						{/if}
					</div>

					<!-- localStorage -->
					<div>
						<div class="mb-2 flex items-center justify-between">
							<span class="text-[11px] font-semibold text-slate-900 dark:text-slate-100">localStorage</span>
							<span class="text-[9px] text-slate-400">{lsEntries.length} keys</span>
						</div>
						{#if lsEntries.length > 0}
							<div
								class="divide-y divide-slate-100 overflow-hidden rounded-xl border border-slate-200 dark:border-white/10"
							>
								{#each lsEntries as entry}
									<div class="bg-white px-2.5 py-1.5 dark:bg-white/5">
										<div class="flex items-start justify-between gap-1.5">
											<div class="min-w-0 flex-1">
												<div
													class="truncate font-mono text-[10px] font-bold text-slate-700 dark:text-slate-200"
												>
													{entry.key}
												</div>
												<div
													class="mt-0.5 truncate font-mono text-[9px] text-slate-400"
												>
													{entry.value.length > 60
														? entry.value.slice(0, 60) + '…'
														: entry.value}
												</div>
											</div>
											<div class="mt-0.5 flex shrink-0 items-center gap-1">
												<span class="text-[8px] text-slate-400">{entry.size}B</span>
												<button
													onclick={() => deleteLsKey(entry.key)}
													class="cursor-pointer px-1 text-[9px] text-red-400 hover:text-red-600"
												>
													del
												</button>
											</div>
										</div>
									</div>
								{/each}
							</div>
						{:else}
							<div class="py-3 text-center text-xs text-slate-400">Leer</div>
						{/if}
					</div>

					<!-- Danger Zone -->
					<div class="border-t border-red-100 pt-3">
						<span class="text-[10px] font-bold uppercase tracking-wide text-red-500"
							>Danger Zone</span
						>
						<div class="mt-2 space-y-1.5">
							{#if confirmAction}
								<div class="rounded-xl bg-red-50 p-3">
									<p class="mb-2 text-[11px] font-medium text-red-700">
										{confirmAction === 'opfs'
											? 'OPFS löschen? (taijobi.db)'
											: confirmAction === 'ls'
												? 'localStorage leeren?'
												: confirmAction === 'chinese'
													? 'Chinese data cache löschen?'
													: 'Alles zurücksetzen? (OPFS + localStorage + Sync)'}
									</p>
									<div class="flex gap-2">
										<button
											onclick={() => {
												if (confirmAction === 'opfs') clearOpfs();
												else if (confirmAction === 'ls') clearLocalStorage();
												else if (confirmAction === 'chinese') {
													clearChineseCache().then(() => window.location.reload());
												} else fullReset();
											}}
											class="cursor-pointer rounded-lg bg-red-500 px-3 py-1 text-[10px] font-bold text-white transition-colors hover:bg-red-600"
										>
											Bestätigen
										</button>
										<button
											onclick={() => {
												confirmAction = null;
											}}
											class="cursor-pointer rounded-lg px-3 py-1 text-[10px] font-medium text-slate-500 dark:text-slate-400 transition-colors hover:text-slate-700 dark:text-slate-200"
										>
											Abbrechen
										</button>
									</div>
								</div>
							{:else}
								<button
									onclick={() => {
										confirmAction = 'opfs';
									}}
									class="w-full cursor-pointer rounded-lg px-2.5 py-1.5 text-left text-[11px] font-medium text-red-600 transition-colors hover:bg-red-50"
								>
									Clear OPFS <span class="text-slate-400">(DB + alle Daten)</span>
								</button>
								<button
									onclick={() => {
										confirmAction = 'ls';
									}}
									class="w-full cursor-pointer rounded-lg px-2.5 py-1.5 text-left text-[11px] font-medium text-red-600 transition-colors hover:bg-red-50"
								>
									Clear localStorage
									<span class="text-slate-400">(Settings, Sync-Key)</span>
								</button>
								<button
									onclick={() => {
										confirmAction = 'full';
									}}
									class="w-full cursor-pointer rounded-lg px-2.5 py-1.5 text-left text-[11px] font-medium text-red-600 transition-colors hover:bg-red-50"
								>
									Full Reset <span class="text-slate-400">(alles)</span>
								</button>
								<button
									onclick={() => {
										confirmAction = 'chinese';
									}}
									class="w-full cursor-pointer rounded-lg px-2.5 py-1.5 text-left text-[11px] font-medium text-red-600 transition-colors hover:bg-red-50"
								>
									Clear Chinese Data <span class="text-slate-400">(OPFS cache)</span>
								</button>
							{/if}
						</div>
					</div>
				</div>
			{:else if activeTab === 'flags'}
				<div class="space-y-2 p-3">
					{#if flagKeys.length === 0}
						<p class="py-4 text-center text-xs text-slate-400 dark:text-slate-500">
							No feature flags defined yet.
						</p>
						<p class="text-center text-[10px] text-slate-400 dark:text-slate-500">
							Add keys to <code class="font-mono">DEFAULT_FEATURES</code> in <code class="font-mono">config.ts</code>.
						</p>
					{:else}
						{#each flagKeys as key (key)}
							<label
								class="flex cursor-pointer items-center justify-between rounded-lg bg-slate-50 px-3 py-2 transition-colors hover:bg-slate-100 dark:bg-white/5 dark:hover:bg-white/10"
							>
								<span class="font-mono text-xs text-slate-700 dark:text-slate-200">{key}</span>
								<input
									type="checkbox"
									checked={featureStore.isEnabled(key)}
									onchange={() => featureStore.toggle(key)}
									class="size-4 cursor-pointer accent-primary"
								/>
							</label>
						{/each}
					{/if}
				</div>
			{:else if activeTab === 'sql'}
				<div class="space-y-2 p-3">
					<textarea
						bind:value={sqlQuery}
						placeholder="SELECT * FROM cards LIMIT 10"
						rows="4"
						spellcheck="false"
						class="w-full resize-y rounded-lg border border-slate-200 bg-slate-50 px-2.5 py-1.5 font-mono text-[11px] text-slate-800 placeholder:text-slate-400 focus:border-primary focus:outline-none dark:border-white/10 dark:bg-white/5 dark:text-slate-200 dark:placeholder:text-slate-500"
					></textarea>
					<div class="flex gap-1.5">
						<button
							onclick={runQuery}
							disabled={!sqlQuery.trim()}
							class="flex-1 cursor-pointer rounded-lg bg-primary px-3 py-1.5 text-[10px] font-bold text-white transition-colors hover:bg-primary/90 disabled:cursor-not-allowed disabled:opacity-40"
						>
							Run
						</button>
						<button
							onclick={runSchema}
							class="cursor-pointer rounded-lg bg-primary/10 px-3 py-1.5 text-[10px] font-bold text-primary hover:bg-primary/20"
						>
							Schema
						</button>
						<button
							onclick={clearSql}
							class="cursor-pointer rounded-lg px-3 py-1.5 text-[10px] font-medium text-slate-500 hover:bg-slate-100 dark:text-slate-400 dark:hover:bg-white/10"
						>
							Clear
						</button>
					</div>

					{#if sqlError}
						<div class="rounded-lg border border-red-200 bg-red-50 p-2 text-[10px] text-red-700 dark:border-red-500/30 dark:bg-red-500/10 dark:text-red-300">
							<span class="font-bold">Error:</span>
							<span class="break-words font-mono">{sqlError}</span>
						</div>
					{/if}

					{#if sqlResult}
						<div class="flex items-center justify-between gap-2 text-[9px] font-medium text-slate-400">
							<span>{sqlResult.count} row{sqlResult.count === 1 ? '' : 's'}</span>
							<div class="flex items-center gap-1.5">
								{#if sqlResult.truncated}
									<span
										class="rounded bg-amber-100 px-1.5 py-0.5 text-amber-700 dark:bg-amber-500/20 dark:text-amber-300"
										>showing first 500</span
									>
								{/if}
								<button
									onclick={exportResultTsv}
									class="cursor-pointer rounded bg-slate-100 px-1.5 py-0.5 font-mono text-[9px] text-slate-600 hover:bg-slate-200 dark:bg-white/10 dark:text-slate-300 dark:hover:bg-white/15"
								>
									TSV
								</button>
							</div>
						</div>
						<div class="overflow-x-auto rounded-lg border border-slate-200 dark:border-white/10">
							<table class="min-w-full text-[10px] text-slate-700 dark:text-slate-200">
								<thead class="bg-slate-50 text-[9px] uppercase tracking-wider text-slate-500 dark:bg-white/5 dark:text-slate-400">
									<tr>
										{#each sqlResult.columns as col (col)}
											<th class="whitespace-nowrap px-2 py-1 text-left font-bold">{col}</th>
										{/each}
									</tr>
								</thead>
								<tbody class="divide-y divide-slate-100 bg-white dark:divide-white/5 dark:bg-slate-900/50">
									{#each sqlResult.rows as row, i (i)}
										<tr>
											{#each row as cell, j (j)}
												<td class="whitespace-nowrap px-2 py-1 font-mono">
													{#if cell === null}
														<span class="italic text-slate-400">&lt;null&gt;</span>
													{:else}
														{stringifyCell(cell)}
													{/if}
												</td>
											{/each}
										</tr>
									{/each}
								</tbody>
							</table>
						</div>
					{/if}

					{#if sqlHistory.length > 0}
						<div class="pt-1">
							<div class="mb-1 text-[9px] font-bold uppercase tracking-wider text-slate-400">
								History
							</div>
							<div class="divide-y divide-slate-100 overflow-hidden rounded-lg border border-slate-200 dark:divide-white/5 dark:border-white/10">
								{#each sqlHistory as entry (entry)}
									<button
										onclick={() => restoreHistory(entry)}
										class="block w-full truncate bg-white px-2 py-1 text-left font-mono text-[10px] text-slate-600 transition-colors hover:bg-slate-50 dark:bg-white/5 dark:text-slate-300 dark:hover:bg-white/10"
										title={entry}
									>
										{entry}
									</button>
								{/each}
							</div>
						</div>
					{/if}
				</div>
			{/if}
		</div>
	</div>
{/if}
