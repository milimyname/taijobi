<script lang="ts">
	import Close from '$lib/icons/Close.svelte';
	import Delete from '$lib/icons/Delete.svelte';
	import Dictionary from '$lib/icons/Dictionary.svelte';
	import Download from '$lib/icons/Download.svelte';
	import DownloadDone from '$lib/icons/DownloadDone.svelte';
	import Explore from '$lib/icons/Explore.svelte';
	import FolderOpen from '$lib/icons/FolderOpen.svelte';
	import Inventory2 from '$lib/icons/Inventory2.svelte';
	import Language from '$lib/icons/Language.svelte';
	import Upload from '$lib/icons/Upload.svelte';
	import UploadFile from '$lib/icons/UploadFile.svelte';
	import {
		installPack,
		removePack,
		restorePack,
		importCsv,
		importApkg,
		exportCsv,
		type Pack,
	} from '$lib/wasm';
	import { onMount, tick } from 'svelte';
	import { page } from '$app/state';
	import { toastStore } from '$lib/toast.svelte';
	import { data } from '$lib/data.svelte';
	import { downloadStore, type DownloadKey } from '$lib/download-state.svelte';
	import { uninstallDictionary } from '$lib/dictionary-data';
	import { exportPackAsJson, downloadPackJson } from '$lib/pack-export';
	import {
		catalogStore,
		tagLabel,
		tagBadgeClass,
		type CatalogEntry,
	} from '$lib/catalog-store.svelte';

	interface CsvPreview {
		filename: string;
		text: string;
		rows: string[][];
		columns: string[];
		totalRows: number;
	}

	let installed: Pack[] = $derived(data.packs());
	let catalog = $derived(catalogStore.entries);
	let loading = $state('');
	let csvPreview: CsvPreview | null = $state(null);
	let importing = $state(false);
	let dragging = $state(false);
	let highlightedId = $state<string | null>(null);

	let zhLoaded = $derived(data.chineseDataLoaded());
	let enLoaded = $derived(data.endictLoaded());
	let deLoaded = $derived(data.dedictLoaded());

	onMount(async () => {
		await catalogStore.ensureLoaded();
		await tick();

		// Deep-link from /marketplace/[id]: `?install={id}` triggers an install
		// (no-op if already installed), then scrolls to the row.
		const installParam = page.url.searchParams.get('install');
		if (installParam) {
			// Strip the param immediately so a later "Entfernen" + refresh
			// doesn't re-install the pack from a stale URL.
			const cleaned = new URL(window.location.href);
			cleaned.searchParams.delete('install');
			window.history.replaceState(window.history.state, '', cleaned.pathname + cleaned.hash);

			await handleInstallById(installParam);
			return;
		}

		// Honor ⌘K deep-link `#pack-{id}` — scroll to + briefly highlight
		// the target row once rendered.
		const hash = location.hash;
		if (hash.startsWith('#pack-')) {
			await flashPack(decodeURIComponent(hash.slice('#pack-'.length)));
		}
	});

	async function handleInstallById(id: string): Promise<void> {
		const entry = catalog.find((e) => e.id === id);
		if (!entry) {
			toastStore.show(`Paket "${id}" nicht im Katalog`);
			return;
		}
		if (isInstalled(entry)) {
			await flashPack(id);
			return;
		}
		await handleInstall(entry);
		await tick();
		await flashPack(id);
	}

	/** Scroll to the pack row and briefly highlight it. */
	async function flashPack(id: string): Promise<void> {
		highlightedId = id;
		await tick();
		const el = document.getElementById(`pack-${id}`);
		if (el) el.scrollIntoView({ behavior: 'smooth', block: 'center' });
		setTimeout(() => (highlightedId = null), 1500);
	}

	function isDictInstalled(id: string): boolean {
		if (id === 'dict-zh') return zhLoaded;
		if (id === 'dict-en') return enLoaded;
		if (id === 'dict-de') return deLoaded;
		return false;
	}

	function isInstalled(entry: CatalogEntry): boolean {
		if (entry.kind === 'dictionary') return isDictInstalled(entry.id);
		return installed.some((p) => p.id === entry.id);
	}

	// ----- grouping -----

	// Installed entries include catalog-tracked packs that are installed,
	// plus any SQLite packs not in the catalog (imports → tag 'personal').
	let installedEntries = $derived.by<CatalogEntry[]>(() => {
		const fromCatalog = catalog.filter(isInstalled);
		const catalogIds = new Set(catalog.map((e) => e.id));
		const orphans = installed
			.filter((p) => !catalogIds.has(p.id))
			.map<CatalogEntry>((p) => ({
				id: p.id,
				kind: 'content',
				tag: 'personal',
				name: p.name,
				language_pair: p.language_pair,
				word_count: p.word_count,
				description: 'Importiertes Paket',
			}));
		return [...orphans, ...fromCatalog];
	});

	const GROUPS: {
		key: string;
		label: string;
		match: (e: CatalogEntry) => boolean;
	}[] = [
		{ key: 'personal', label: 'Eigene', match: (e) => e.tag === 'personal' },
		{ key: 'dictionary', label: 'Wörterbücher', match: (e) => e.kind === 'dictionary' },
		{
			key: 'content-official',
			label: 'Lehrbücher',
			match: (e) => e.kind === 'content' && e.tag === 'official',
		},
		{ key: 'community', label: 'Community', match: (e) => e.tag === 'community' },
	];

	function groupEntries(list: CatalogEntry[]) {
		return GROUPS.map((g) => ({ ...g, entries: list.filter(g.match) })).filter(
			(g) => g.entries.length > 0,
		);
	}

	let installedGroups = $derived(groupEntries(installedEntries));

	// ----- install / remove -----

	async function handleInstall(entry: CatalogEntry) {
		if (entry.kind === 'dictionary') {
			if (downloadStore.active !== null) return;
			await downloadStore.start(entry.language_pair as DownloadKey);
			return;
		}
		loading = entry.id;
		try {
			const res = await fetch(`/packs/${entry.id}.json`);
			const json = await res.text();
			await installPack(json);
		} catch (e) {
			toastStore.show(e instanceof Error ? e.message : 'Install failed');
		} finally {
			loading = '';
		}
	}

	function handleExportPack(entry: CatalogEntry) {
		const result = exportPackAsJson(entry.id);
		if (!result.ok) {
			toastStore.show(`Export fehlgeschlagen: ${result.error}`);
			return;
		}
		downloadPackJson(result);
		toastStore.show(
			`${result.filename} heruntergeladen (${result.wordCount} Wörter) — öffne eine PR in packs/community/`,
		);
	}

	async function handleRemove(entry: CatalogEntry) {
		if (entry.kind === 'dictionary') {
			try {
				await uninstallDictionary(entry.language_pair as DownloadKey);
				data.bump();
				toastStore.show(`${entry.name} entfernt`);
			} catch (e) {
				toastStore.show(e instanceof Error ? e.message : 'Entfernen fehlgeschlagen');
			}
			return;
		}
		const pack = installed.find((p) => p.id === entry.id);
		try {
			await removePack(entry.id);
			toastStore.show(`${pack?.name ?? 'Pack'} gelöscht`, async () => {
				await restorePack(entry.id);
			});
		} catch (e) {
			toastStore.show(e instanceof Error ? e.message : 'Löschen fehlgeschlagen');
		}
	}

	// ----- import / export -----

	function parseCsvPreview(text: string, filename: string): CsvPreview {
		const lines = text.split('\n').filter((l) => l.trim().length > 0);
		const delimiter = text.includes('\t') ? '\t' : text.includes(';') ? ';' : ',';
		const rows = lines.map((l) => l.split(delimiter).map((f) => f.trim().replace(/^"|"$/g, '')));
		const knownHeaders = [
			'word', 'hanzi', 'front', 'chinese', 'character', 'vocabulary', 'term',
			'pinyin', 'reading', 'pronunciation',
			'meaning', 'english', 'back', 'deutsch', 'definition', 'translation'
		];
		const firstRow = rows[0] ?? [];
		const hasHeader = firstRow.some((f) => knownHeaders.includes(f.toLowerCase()));
		const columns = hasHeader ? firstRow : firstRow.map((_, i) => `Spalte ${i + 1}`);
		const dataRows = hasHeader ? rows.slice(1) : rows;
		return {
			filename,
			text,
			rows: dataRows.slice(0, 5),
			columns,
			totalRows: dataRows.length
		};
	}

	function handleFile(file: File) {
		if (!file) return;
		const name = file.name.replace(/\.\w+$/, '');

		if (file.name.endsWith('.apkg')) {
			const reader = new FileReader();
			reader.addEventListener('load', async () => {
				importing = true;
				try {
					const beforeIds = new Set(data.packs().map((p) => p.id));
					const count = await importApkg(reader.result as ArrayBuffer, name);
					toastStore.show(`${count} Karten aus .apkg importiert`);
					const newPack = data.packs().find((p) => !beforeIds.has(p.id));
					if (newPack) await flashPack(newPack.id);
				} catch (e) {
					toastStore.show(e instanceof Error ? e.message : '.apkg import failed');
				} finally {
					importing = false;
				}
			});
			reader.readAsArrayBuffer(file);
			return;
		}

		const reader = new FileReader();
		reader.addEventListener('load', () => {
			const text = reader.result as string;
			csvPreview = parseCsvPreview(text, name);
		});
		reader.readAsText(file);
	}

	function handleDrop(e: DragEvent) {
		dragging = false;
		const file = e.dataTransfer?.files[0];
		if (file) handleFile(file);
	}

	function handleFileInput(e: Event) {
		const input = e.target as HTMLInputElement;
		const file = input.files?.[0];
		if (file) handleFile(file);
		input.value = '';
	}

	async function handleCsvImport() {
		if (!csvPreview) return;
		importing = true;
		try {
			const beforeIds = new Set(data.packs().map((p) => p.id));
			const count = await importCsv(csvPreview.text, csvPreview.filename);
			toastStore.show(`${count} Karten importiert`);
			csvPreview = null;
			// Pack id is derived deterministically inside Zig (`csv-{fnv1a}` /
			// `apkg-{fnv1a}`) but rather than mirror that hash, just diff the
			// installed-pack set — the new entry is whatever wasn't there before.
			const newPack = data.packs().find((p) => !beforeIds.has(p.id));
			if (newPack) await flashPack(newPack.id);
		} catch (e) {
			toastStore.show(e instanceof Error ? e.message : 'Import failed');
		} finally {
			importing = false;
		}
	}

	function handleExport() {
		try {
			const csv = exportCsv();
			const blob = new Blob([csv], { type: 'text/tab-separated-values' });
			const url = URL.createObjectURL(blob);
			const a = document.createElement('a');
			a.href = url;
			a.download = 'taijobi-export.tsv';
			a.click();
			URL.revokeObjectURL(url);
		} catch (e) {
			toastStore.show(e instanceof Error ? e.message : 'Export failed');
		}
	}
</script>

<svelte:head>
	<title>Pakete — Taijobi</title>
</svelte:head>

<!-- Marketplace banner -->
<section class="mt-4">
	<a
		href="/marketplace"
		class="group flex items-center justify-between gap-4 rounded-2xl border border-primary/30 bg-primary/5 px-5 py-4 transition-colors hover:border-primary hover:bg-primary/10 dark:border-primary/30 dark:bg-primary/10"
	>
		<div class="flex items-center gap-3">
			<div class="flex size-10 shrink-0 items-center justify-center rounded-xl bg-primary/15">
				<Explore class="text-primary" />
			</div>
			<div>
				<p class="text-sm font-bold text-slate-900 dark:text-slate-100">
					Pakete entdecken
				</p>
				<p class="text-xs text-slate-500 dark:text-slate-400">
					HSK, L&oacute;ng neu, Community-Decks und W&ouml;rterb&uuml;cher
				</p>
			</div>
		</div>
		<span class="hidden text-sm font-medium text-primary transition-transform group-hover:translate-x-1 dark:text-accent sm:inline">
			Marktplatz &rarr;
		</span>
	</a>
</section>

<!-- Installed Packs -->
{#if installedGroups.length > 0}
	<section class="mt-6">
		<h2 class="mb-4 flex items-center gap-2 text-lg font-bold text-slate-900 dark:text-slate-100">
			<DownloadDone class="text-primary" />
			Installiert
		</h2>
		<div class="space-y-6">
			{#each installedGroups as group (group.key)}
				<div class="space-y-3">
					<p class="text-[11px] font-bold uppercase tracking-wider text-primary">{group.label}</p>
					{#each group.entries as entry (entry.id)}
						{@const pack = installed.find((p) => p.id === entry.id)}
						<div
							id="pack-{entry.id}"
							class="rounded-2xl border bg-white p-4 shadow-sm transition-colors dark:bg-white/5 {highlightedId === entry.id
								? 'border-primary ring-2 ring-primary/30'
								: 'border-slate-100 dark:border-white/5'}"
						>
							<div class="mb-3 flex items-start gap-4">
								<div class="flex size-16 shrink-0 items-center justify-center rounded-lg bg-primary/10">
									{#if entry.kind === 'dictionary'}
										<Dictionary class="text-3xl text-primary" />
									{:else}
										<Language class="text-3xl text-primary" />
									{/if}
								</div>
								<div class="min-w-0 flex-1">
									<div class="flex items-center gap-2">
										<h3 class="truncate text-lg font-bold text-slate-900 dark:text-slate-100">{entry.name}</h3>
										<span class="shrink-0 rounded-md px-1.5 py-0.5 text-[10px] font-bold uppercase tracking-wider {tagBadgeClass(entry.tag)}">
											{tagLabel(entry.tag)}
										</span>
									</div>
									<p class="text-sm text-slate-500 dark:text-slate-400">
										{#if entry.kind === 'dictionary'}
											{entry.description}
										{:else if pack}
											{pack.language_pair} &bull; {pack.word_count} W&ouml;rter
										{:else}
											{entry.language_pair} &bull; {entry.word_count ?? 0} W&ouml;rter
										{/if}
									</p>
								</div>
							</div>
							{#if entry.kind === 'content'}
								<div class="flex items-center justify-between gap-2">
									<a href="/lessons/{entry.id}" class="text-sm font-medium text-primary">
										Lektionen anzeigen &rarr;
									</a>
									<div class="flex items-center gap-1">
										{#if entry.tag === 'personal'}
											<button
												onclick={() => handleExportPack(entry)}
												title="Als Community-Pack JSON exportieren (für PR nach packs/community/)"
												class="flex items-center gap-1 rounded-lg px-3 py-1.5 text-sm font-medium text-primary transition-colors hover:bg-primary/10 dark:text-accent dark:hover:bg-accent/10"
											>
												<Upload class="text-sm" />
												Exportieren
											</button>
										{/if}
										<button
											onclick={() => handleRemove(entry)}
											class="flex items-center gap-1 rounded-lg px-3 py-1.5 text-sm font-medium text-red-600 transition-colors hover:bg-red-50 dark:text-red-400 dark:hover:bg-red-500/10"
										>
											<Delete class="text-sm" />
											Entfernen
										</button>
									</div>
								</div>
							{:else}
								<div class="flex justify-end">
									<button
										onclick={() => handleRemove(entry)}
										class="flex items-center gap-1 rounded-lg px-3 py-1.5 text-sm font-medium text-red-600 transition-colors hover:bg-red-50 dark:text-red-400 dark:hover:bg-red-500/10"
									>
										<Delete class="text-sm" />
										Entfernen
									</button>
								</div>
							{/if}
						</div>
					{/each}
				</div>
			{/each}
		</div>
	</section>
{/if}

<!-- Active dictionary download (e.g. user just clicked install on /marketplace
     and the page navigated here while the dict download is still streaming).
     The /packs surface no longer has an "Available" section, so without this
     the progress bar would be invisible. -->
{#if downloadStore.active !== null}
	{@const activeId =
		downloadStore.active === 'zh' ? 'dict-zh' : downloadStore.active === 'en' ? 'dict-en' : 'dict-de'}
	{@const activeEntry = catalog.find((e) => e.id === activeId)}
	{#if activeEntry}
		<section class="mt-6">
			<div class="rounded-2xl border border-primary/30 bg-primary/5 p-4 dark:border-primary/30 dark:bg-primary/10">
				<div class="flex items-start gap-4">
					<div class="flex size-12 shrink-0 items-center justify-center rounded-lg bg-primary/15">
						<Dictionary class="text-2xl text-primary" />
					</div>
					<div class="min-w-0 flex-1">
						<p class="text-sm font-bold text-slate-900 dark:text-slate-100">
							{activeEntry.name} wird heruntergeladen&hellip;
						</p>
						<p class="text-xs text-slate-500 dark:text-slate-400">
							{#if downloadStore.total > 0}
								{Math.round((downloadStore.progress / downloadStore.total) * 100)}% &mdash;
								Du kannst die Seite verlassen, der Download l&auml;uft weiter.
							{:else}
								Herunterladen&hellip;
							{/if}
						</p>
					</div>
				</div>
				{#if downloadStore.total > 0}
					<div class="mt-3 h-1.5 w-full overflow-hidden rounded-full bg-slate-100 dark:bg-white/10">
						<div
							class="h-full rounded-full bg-primary transition-all duration-200"
							style="width: {Math.round((downloadStore.progress / downloadStore.total) * 100)}%"
						></div>
					</div>
				{/if}
			</div>
		</section>
	{/if}
{/if}

<!-- Empty / loading state -->
{#if catalog.length === 0 && installed.length === 0}
	<div
		class="mt-8 rounded-2xl border border-slate-100 bg-white p-8 text-center shadow-sm dark:border-white/5 dark:bg-white/5"
	>
		<Inventory2 class="mx-auto mb-2 block text-[32px] text-slate-300 dark:text-slate-500" />
		<p class="text-sm text-slate-500 dark:text-slate-400">Lade Pakete...</p>
	</div>
{:else if installedGroups.length === 0}
	<div
		class="mt-8 rounded-2xl border border-slate-100 bg-white p-8 text-center shadow-sm dark:border-white/5 dark:bg-white/5"
	>
		<Inventory2 class="mx-auto mb-2 block text-[32px] text-slate-300 dark:text-slate-500" />
		<p class="text-sm text-slate-500 dark:text-slate-400">
			Noch keine Pakete installiert.
		</p>
		<a
			href="/marketplace"
			class="mt-3 inline-flex items-center gap-1 text-sm font-medium text-primary dark:text-accent"
		>
			Pakete im Marktplatz entdecken &rarr;
		</a>
	</div>
{/if}

<!-- Eigene Pakete (Import / Export) -->
<section class="mt-10">
	<div class="mb-4">
		<h2 class="flex items-center gap-2 text-lg font-bold text-slate-900 dark:text-slate-100">
			<UploadFile class="text-primary" />
			Eigene Pakete
		</h2>
		<p class="mt-1 text-sm text-slate-500 dark:text-slate-400">
			CSV, TSV oder Anki-Export (.apkg). Anki-Decks werden direkt ohne Vorschau importiert.
		</p>
	</div>

	<div class="flex gap-3">
		<button
			onclick={handleExport}
			class="flex items-center gap-2 rounded-xl border border-slate-100 bg-white px-4 py-2.5 text-sm font-medium text-slate-700 shadow-sm transition-colors hover:bg-slate-50 dark:border-white/5 dark:bg-white/5 dark:text-slate-200 dark:hover:bg-white/10"
		>
			<Download class="text-sm" />
			Alle Karten exportieren (TSV)
		</button>
	</div>

	<!-- Drop zone -->
	<div
		class="mt-4 rounded-2xl border-2 border-dashed p-6 text-center transition-colors {dragging
			? 'border-primary bg-primary/5'
			: 'border-slate-200 bg-white dark:border-white/10 dark:bg-white/5'}"
		role="region"
		aria-label="Datei importieren"
		ondragover={(e) => { e.preventDefault(); dragging = true; }}
		ondragleave={() => { dragging = false; }}
		ondrop={(e) => { e.preventDefault(); handleDrop(e); }}
	>
		<UploadFile class="mx-auto mb-2 block text-[32px] text-slate-300 dark:text-slate-500" />
		<p class="text-sm text-slate-500 dark:text-slate-400">
			Datei hierher ziehen
		</p>
		<p class="mt-1 text-xs text-slate-400 dark:text-slate-500">
			Unterstützt: .csv, .tsv, .apkg
		</p>
		<label class="mt-3 inline-flex cursor-pointer items-center gap-1 rounded-lg bg-primary/10 px-4 py-2 text-sm font-medium text-primary transition-colors hover:bg-primary/20">
			<FolderOpen class="text-sm" />
			Datei ausw&auml;hlen
			<input type="file" accept=".csv,.tsv,.txt,.apkg" class="hidden" onchange={handleFileInput} />
		</label>
	</div>

	<!-- CSV Preview -->
	{#if csvPreview}
		<div
			class="mt-4 rounded-2xl border border-slate-100 bg-white p-4 shadow-sm dark:border-white/5 dark:bg-white/5"
		>
			<div class="mb-3 flex items-center justify-between">
				<div>
					<h3 class="font-bold text-slate-900 dark:text-slate-100">{csvPreview.filename}</h3>
					<p class="text-sm text-slate-500 dark:text-slate-400">{csvPreview.totalRows} Zeilen erkannt</p>
				</div>
				<button
					onclick={() => { csvPreview = null; }}
					class="rounded-lg p-1.5 text-slate-400 transition-colors hover:bg-slate-100 hover:text-slate-600 dark:hover:bg-white/10 dark:hover:text-slate-200"
				>
					<Close class="text-sm" />
				</button>
			</div>

			<div class="overflow-x-auto">
				<table class="w-full text-left text-sm">
					<thead>
						<tr class="border-b border-slate-100 dark:border-white/5">
							{#each csvPreview.columns as col}
								<th class="px-3 py-2 text-xs font-bold uppercase tracking-wider text-primary">{col}</th>
							{/each}
						</tr>
					</thead>
					<tbody>
						{#each csvPreview.rows as row}
							<tr class="border-b border-slate-50 dark:border-white/5">
								{#each row as cell}
									<td class="max-w-[200px] truncate px-3 py-2 text-slate-700 dark:text-slate-200">{cell}</td>
								{/each}
							</tr>
						{/each}
					</tbody>
				</table>
			</div>

			{#if csvPreview.totalRows > 5}
				<p class="mt-2 text-center text-xs text-slate-400 dark:text-slate-500">
					... und {csvPreview.totalRows - 5} weitere Zeilen
				</p>
			{/if}

			<button
				onclick={handleCsvImport}
				disabled={importing}
				class="mt-4 flex w-full items-center justify-center gap-2 rounded-xl bg-primary py-2.5 font-medium text-white transition-colors hover:bg-primary/90 disabled:opacity-50"
			>
				{#if importing}
					Importiere...
				{:else}
					<Upload class="text-sm" />
					{csvPreview.totalRows} Karten importieren
				{/if}
			</button>
		</div>
	{/if}
</section>
