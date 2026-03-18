<script lang="ts">
	import {
		getPacks,
		installPack,
		removePack,
		importCsv,
		importApkg,
		exportCsv,
		type Pack
	} from '$lib/wasm';
	import { onMount, onDestroy } from 'svelte';
	import { toastStore } from '$lib/toast.svelte';

	interface CatalogEntry {
		id: string;
		name: string;
		language_pair: string;
		word_count: number;
		description: string;
	}

	interface CsvPreview {
		filename: string;
		text: string;
		rows: string[][];
		columns: string[];
		totalRows: number;
	}

	let installed: Pack[] = $state([]);
	let catalog: CatalogEntry[] = $state([]);
	let loading = $state('');
	let csvPreview: CsvPreview | null = $state(null);
	let importing = $state(false);
	let dragging = $state(false);

	function refresh() {
		installed = getPacks();
	}

	onMount(async () => {
		refresh();
		try {
			const res = await fetch('/packs/catalog.json');
			catalog = await res.json();
		} catch {
			console.error('Failed to load pack catalog');
		}
	});

	let available = $derived(
		catalog.filter((c) => !installed.some((p) => p.id === c.id))
	);

	async function handleInstall(id: string) {
		loading = id;
		try {
			const res = await fetch(`/packs/${id}.json`);
			const json = await res.text();
			await installPack(json);
			refresh();
		} catch (e) {
			toastStore.show(e instanceof Error ? e.message : 'Install failed');
		} finally {
			loading = '';
		}
	}

	async function handleRemove(id: string) {
		try {
			await removePack(id);
			refresh();
		} catch (e) {
			toastStore.show(e instanceof Error ? e.message : 'Remove failed');
		}
	}

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
			// Binary .apkg — import directly (no text preview)
			const reader = new FileReader();
			reader.onload = async () => {
				importing = true;
				try {
					const count = await importApkg(reader.result as ArrayBuffer, name);
					toastStore.show(`${count} Karten aus .apkg importiert`);
					refresh();
				} catch (e) {
					toastStore.show(e instanceof Error ? e.message : '.apkg import failed');
				} finally {
					importing = false;
				}
			};
			reader.readAsArrayBuffer(file);
			return;
		}

		// CSV/TSV — show text preview
		const reader = new FileReader();
		reader.onload = () => {
			const text = reader.result as string;
			csvPreview = parseCsvPreview(text, name);
		};
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
			const count = await importCsv(csvPreview.text, csvPreview.filename);
			toastStore.show(`${count} Karten importiert`);
			csvPreview = null;
			refresh();
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

<!-- Import/Export -->
<section class="mt-6">
	<h2 class="mb-4 flex items-center gap-2 text-lg font-bold text-slate-900">
		<span class="material-symbols-outlined text-primary">swap_vert</span>
		Import / Export
	</h2>

	<div class="flex gap-3">
		<button
			onclick={handleExport}
			class="flex items-center gap-2 rounded-xl border border-slate-100 bg-white px-4 py-2.5 text-sm font-medium text-slate-700 shadow-sm transition-colors hover:bg-slate-50"
		>
			<span class="material-symbols-outlined text-sm">download</span>
			CSV exportieren
		</button>
	</div>

	<!-- Drop zone -->
	<div
		class="mt-4 rounded-2xl border-2 border-dashed p-6 text-center transition-colors {dragging ? 'border-primary bg-primary/5' : 'border-slate-200 bg-white'}"
		role="region"
		aria-label="CSV Import"
		ondragover={(e) => { e.preventDefault(); dragging = true; }}
		ondragleave={() => { dragging = false; }}
		ondrop={(e) => { e.preventDefault(); handleDrop(e); }}
	>
		<span class="material-symbols-outlined mb-2 text-[32px] text-slate-300">upload_file</span>
		<p class="text-sm text-slate-500">
			CSV/TSV oder .apkg hierher ziehen
		</p>
		<p class="mt-1 text-xs text-slate-400">oder</p>
		<label class="mt-2 inline-flex cursor-pointer items-center gap-1 rounded-lg bg-primary/10 px-4 py-2 text-sm font-medium text-primary transition-colors hover:bg-primary/20">
			<span class="material-symbols-outlined text-sm">folder_open</span>
			Datei ausw&auml;hlen
			<input type="file" accept=".csv,.tsv,.txt,.apkg" class="hidden" onchange={handleFileInput} />
		</label>
	</div>

	<!-- CSV Preview -->
	{#if csvPreview}
		<div class="mt-4 rounded-2xl border border-slate-100 bg-white p-4 shadow-sm">
			<div class="mb-3 flex items-center justify-between">
				<div>
					<h3 class="font-bold text-slate-900">{csvPreview.filename}</h3>
					<p class="text-sm text-slate-500">{csvPreview.totalRows} Zeilen erkannt</p>
				</div>
				<button
					onclick={() => { csvPreview = null; }}
					class="rounded-lg p-1.5 text-slate-400 transition-colors hover:bg-slate-100 hover:text-slate-600"
				>
					<span class="material-symbols-outlined text-sm">close</span>
				</button>
			</div>

			<div class="overflow-x-auto">
				<table class="w-full text-left text-sm">
					<thead>
						<tr class="border-b border-slate-100">
							{#each csvPreview.columns as col}
								<th class="px-3 py-2 text-xs font-bold uppercase tracking-wider text-primary">{col}</th>
							{/each}
						</tr>
					</thead>
					<tbody>
						{#each csvPreview.rows as row}
							<tr class="border-b border-slate-50">
								{#each row as cell}
									<td class="max-w-[200px] truncate px-3 py-2 text-slate-700">{cell}</td>
								{/each}
							</tr>
						{/each}
					</tbody>
				</table>
			</div>

			{#if csvPreview.totalRows > 5}
				<p class="mt-2 text-center text-xs text-slate-400">
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
					<span class="material-symbols-outlined text-sm">upload</span>
					{csvPreview.totalRows} Karten importieren
				{/if}
			</button>
		</div>
	{/if}
</section>

<!-- Installed Packs -->
{#if installed.length > 0}
	<section class="mt-6">
		<h2 class="mb-4 flex items-center gap-2 text-lg font-bold text-slate-900">
			<span class="material-symbols-outlined text-primary">download_done</span>
			Installiert
		</h2>
		<div class="space-y-4">
			{#each installed as pack (pack.id)}
				<div
					class="rounded-2xl border border-slate-100 bg-white p-4 shadow-sm"
				>
					<div class="mb-3 flex items-start gap-4">
						<div
							class="flex size-16 shrink-0 items-center justify-center rounded-lg bg-primary/10"
						>
							<span class="material-symbols-outlined text-3xl text-primary">language</span>
						</div>
						<div class="min-w-0 flex-1">
							<h3 class="truncate text-lg font-bold">{pack.name}</h3>
							<p class="text-sm text-slate-500">
								{pack.language_pair} &bull; {pack.word_count} W&ouml;rter
							</p>
						</div>
					</div>
					<div class="flex justify-between">
						<a
							href="/lessons/{pack.id}"
							class="text-sm font-medium text-primary"
						>
							Lektionen anzeigen &rarr;
						</a>
						<button
							onclick={() => handleRemove(pack.id)}
							class="flex items-center gap-1 rounded-lg px-3 py-1.5 text-sm font-medium text-red-600 transition-colors hover:bg-red-50"
						>
							<span class="material-symbols-outlined text-sm">delete</span>
							Entfernen
						</button>
					</div>
				</div>
			{/each}
		</div>
	</section>
{/if}

<!-- Available Packs -->
{#if available.length > 0}
	<section class="mt-8">
		<h2 class="mb-4 flex items-center gap-2 text-lg font-bold text-slate-900">
			<span class="material-symbols-outlined text-primary">explore</span>
			Verf&uuml;gbar
		</h2>
		<div class="space-y-4">
			{#each available as entry (entry.id)}
				<div
					class="rounded-2xl border border-slate-100 bg-white p-4 shadow-sm"
				>
					<div class="mb-3 flex items-start gap-4">
						<div
							class="flex size-16 shrink-0 items-center justify-center rounded-lg bg-primary/5"
						>
							<span class="material-symbols-outlined text-3xl text-primary">inventory_2</span>
						</div>
						<div class="min-w-0 flex-1">
							<h3 class="truncate text-lg font-bold">{entry.name}</h3>
							<p class="text-sm text-slate-500">{entry.description}</p>
							<p class="text-xs text-slate-400">{entry.word_count} W&ouml;rter</p>
						</div>
					</div>
					<button
						onclick={() => handleInstall(entry.id)}
						disabled={loading === entry.id}
						class="flex w-full items-center justify-center gap-2 rounded-xl bg-primary py-2.5 font-medium text-white transition-colors hover:bg-primary/90 disabled:opacity-50"
					>
						{#if loading === entry.id}
							Installiere...
						{:else}
							<span class="material-symbols-outlined text-sm">download</span>
							Installieren
						{/if}
					</button>
				</div>
			{/each}
		</div>
	</section>
{/if}

{#if installed.length === 0 && available.length === 0}
	<div class="mt-8 rounded-2xl border border-slate-100 bg-white p-8 text-center shadow-sm">
		<span class="material-symbols-outlined mb-2 text-[32px] text-slate-300">inventory_2</span>
		<p class="text-sm text-slate-500">Lade Pakete...</p>
	</div>
{/if}
