<script lang="ts">
	import ArrowBack from '$lib/icons/ArrowBack.svelte';
	import Book2 from '$lib/icons/Book2.svelte';
	import Check from '$lib/icons/Check.svelte';
	import UploadFile from '$lib/icons/UploadFile.svelte';
	import { goto } from '$app/navigation';
	import { parseClippings, wordCount, type KindleEntry } from '$lib/kindle';
	import { bulkAddLexicon } from '$lib/wasm';
	import { toastStore } from '$lib/toast.svelte';

	type Filter = 'all' | 'short' | 'long';

	let entries = $state<KindleEntry[]>([]);
	let selected = $state<Set<number>>(new Set());
	let filter = $state<Filter>('all');
	let fileName = $state('');
	let parseError = $state('');

	// Import progress — bulk path commits in one transaction, so no per-word
	// progress; we just show a spinner + final result.
	let importing = $state(false);

	// Drag state for the drop zone
	let dragging = $state(false);

	// Swallow drag-over/drop on the window so the browser doesn't navigate
	// to the file when the user releases slightly outside the drop zone.
	// Our zone handlers stopPropagation, so this never preempts them.
	$effect(() => {
		const over = (e: DragEvent) => e.preventDefault();
		const drop = (e: DragEvent) => e.preventDefault();
		window.addEventListener('dragover', over);
		window.addEventListener('drop', drop);
		return () => {
			window.removeEventListener('dragover', over);
			window.removeEventListener('drop', drop);
		};
	});

	const filtered = $derived.by(() => {
		if (filter === 'all') return entries.map((e, i) => ({ e, i }));
		if (filter === 'short')
			return entries.map((e, i) => ({ e, i })).filter(({ e }) => wordCount(e.text) <= 5);
		return entries.map((e, i) => ({ e, i })).filter(({ e }) => wordCount(e.text) > 5);
	});

	const visibleIndices = $derived(filtered.map(({ i }) => i));
	const allVisibleSelected = $derived(
		visibleIndices.length > 0 && visibleIndices.every((i) => selected.has(i)),
	);
	const selectedCount = $derived(selected.size);
	const bookCount = $derived(new Set(entries.map((e) => e.book)).size);

	function isTxt(file: File): boolean {
		// file.type is unreliable on some OSes, so accept either.
		return /\.txt$/i.test(file.name) || file.type === 'text/plain';
	}

	async function handleFiles(files: File[]) {
		const txt = files.filter(isTxt);
		if (txt.length === 0) {
			parseError = 'Bitte .txt-Dateien ablegen (My Clippings.txt vom Kindle).';
			return;
		}
		parseError = '';
		fileName = txt.length === 1 ? txt[0].name : `${txt.length} Dateien`;
		const merged: KindleEntry[] = [];
		const errors: string[] = [];
		for (const file of txt) {
			try {
				const raw = await file.text();
				const parsed = parseClippings(raw);
				merged.push(...parsed);
			} catch (err) {
				errors.push(`${file.name}: ${err instanceof Error ? err.message : 'Parse-Fehler'}`);
			}
		}
		entries = merged;
		selected = new Set(merged.map((_, i) => i));
		if (merged.length === 0 && errors.length === 0) {
			parseError =
				'Keine Clippings gefunden. Stelle sicher, dass du My Clippings.txt vom Kindle hochgeladen hast.';
		} else if (errors.length > 0) {
			parseError = errors.join(' · ');
		}
	}

	function onFileChange(e: Event) {
		const input = e.currentTarget as HTMLInputElement;
		const files = input.files ? Array.from(input.files) : [];
		if (files.length > 0) handleFiles(files);
		// Reset so the same file can be picked again after a reset
		input.value = '';
	}

	async function handleDrop(e: DragEvent) {
		dragging = false;
		const files = e.dataTransfer?.files ? Array.from(e.dataTransfer.files) : [];
		if (files.length > 0) {
			handleFiles(files);
			return;
		}

		// Fallback for editor-native drags (VS Code, Cursor, Sublime): those
		// put the file content or path in items[] as 'string' kind rather than
		// in files[]. If the payload looks like a clippings file (contains the
		// `==========` separator), treat it as dropped content.
		const items = e.dataTransfer?.items;
		if (items) {
			for (let i = 0; i < items.length; i++) {
				const item = items[i];
				if (item.kind !== 'string' || item.type !== 'text/plain') continue;
				const text = await new Promise<string>((resolve) => item.getAsString(resolve));
				if (text.includes('==========')) {
					const synthetic = new File([text], 'dropped.txt', { type: 'text/plain' });
					handleFiles([synthetic]);
					return;
				}
			}
		}

		parseError =
			'Keine Datei erkannt. Ziehe die Datei aus dem Finder/Datei-Explorer — oder aus dem ge\u00f6ffneten Editor-Tab (nicht aus der Seitenleiste des Editors). Alternativ auf "Datei ausw\u00e4hlen" klicken.';
	}

	async function loadSample() {
		fileName = 'my-clippings.txt (Beispiel)';
		parseError = '';
		try {
			const resp = await fetch('/examples/my-clippings.txt');
			if (!resp.ok) throw new Error('Beispiel-Datei nicht gefunden');
			const raw = await resp.text();
			const parsed = parseClippings(raw);
			entries = parsed;
			selected = new Set(parsed.map((_, i) => i));
		} catch (err) {
			parseError = err instanceof Error ? err.message : 'Fehler beim Laden';
		}
	}

	function toggleEntry(i: number) {
		const next = new Set(selected);
		if (next.has(i)) next.delete(i);
		else next.add(i);
		selected = next;
	}

	function toggleAllVisible() {
		const next = new Set(selected);
		if (allVisibleSelected) {
			for (const i of visibleIndices) next.delete(i);
		} else {
			for (const i of visibleIndices) next.add(i);
		}
		selected = next;
	}

	async function doImport() {
		if (importing || selectedCount === 0) return;
		importing = true;
		const toImport = [...selected].sort((a, b) => a - b).map((i) => entries[i].text);
		try {
			const { added, skipped, failed } = await bulkAddLexicon(toImport);
			const parts: string[] = [];
			if (added > 0) parts.push(`${added} importiert`);
			if (skipped > 0) parts.push(`${skipped} schon vorhanden`);
			if (failed > 0) parts.push(`${failed} fehlgeschlagen`);
			toastStore.show(parts.length > 0 ? parts.join(', ') : 'Nichts importiert');
			if (failed === 0) goto('/lexicon');
		} catch (e) {
			toastStore.show(`Import fehlgeschlagen: ${e instanceof Error ? e.message : 'Fehler'}`);
		} finally {
			importing = false;
		}
	}

	function reset() {
		entries = [];
		selected = new Set();
		fileName = '';
		parseError = '';
	}
</script>

<div class="pt-2">
	<!-- Breadcrumb -->
	<a
		href="/lexicon"
		class="mb-4 inline-flex items-center gap-1 text-xs font-bold uppercase tracking-wider text-primary hover:underline"
	>
		<ArrowBack class="text-[14px]" /> Lexikon
	</a>

	<h1 class="text-2xl font-bold text-slate-900 dark:text-slate-100">Kindle-Import</h1>
	<p class="mt-1 text-sm text-slate-500 dark:text-slate-400">
		W&auml;hle eine oder mehrere <code class="font-mono text-xs">My&nbsp;Clippings.txt</code>-Dateien
		vom Kindle. Markierungen werden ins Lexikon importiert &mdash; Sprache wird automatisch erkannt.
	</p>

	<!-- Step 1: File picker + drop zone -->
	{#if entries.length === 0}
		<div
			role="region"
			aria-label="Drop zone für My Clippings.txt"
			ondragenter={(e) => {
				e.preventDefault();
				e.stopPropagation();
				dragging = true;
			}}
			ondragover={(e) => {
				e.preventDefault();
				e.stopPropagation();
				if (e.dataTransfer) e.dataTransfer.dropEffect = 'copy';
				dragging = true;
			}}
			ondragleave={(e) => {
				if (e.currentTarget === e.target) dragging = false;
			}}
			ondrop={(e) => {
				e.preventDefault();
				e.stopPropagation();
				handleDrop(e);
			}}
			class="relative mt-6 flex flex-col items-center rounded-2xl border-2 border-dashed p-8 text-center shadow-sm transition-colors {dragging
				? 'border-primary bg-primary/10'
				: 'border-slate-200 bg-white dark:border-white/10 dark:bg-white/5'}"
		>
			<div class="mb-3 flex size-14 items-center justify-center rounded-2xl bg-primary/10">
				<UploadFile class="text-[28px] text-primary" />
			</div>
			<p class="mb-3 text-sm text-slate-500 dark:text-slate-400">
				{dragging ? 'Jetzt loslassen …' : 'Dateien hierher ziehen'}
			</p>
			<label
				class="inline-flex cursor-pointer items-center gap-2 rounded-xl bg-primary px-5 py-2.5 text-sm font-bold text-white shadow-sm transition-colors hover:bg-primary/90"
			>
				Dateien ausw&auml;hlen
				<input
					type="file"
					accept=".txt,text/plain"
					multiple
					onchange={onFileChange}
					class="hidden"
				/>
			</label>
			<p class="mt-1 text-[10px] text-slate-400 dark:text-slate-500">
				mehrere .txt-Dateien m&ouml;glich
			</p>
			<p class="mt-3 text-xs text-slate-400 dark:text-slate-500">
				oder
				<button onclick={loadSample} class="font-bold text-primary hover:underline">
					Beispiel-Datei laden
				</button>
			</p>
			{#if parseError}
				<p class="mt-3 text-xs text-red-600 dark:text-red-400">{parseError}</p>
			{/if}
		</div>

		<!-- Help -->
		<div class="mt-6 rounded-2xl bg-slate-50 p-4 text-xs text-slate-600 dark:bg-white/5 dark:text-slate-400">
			<p class="mb-1 font-bold uppercase tracking-wider text-primary">Hinweis</p>
			<p>
				Verbinde deinen Kindle per USB und kopiere die Datei aus
				<code class="font-mono">documents/My&nbsp;Clippings.txt</code>. Alle Markierungen werden
				lokal in deinem Browser verarbeitet &mdash; nichts wird hochgeladen.
			</p>
		</div>
	{:else}
		<!-- Step 2: Review + select -->
		<div class="mt-4 flex items-center justify-between rounded-xl bg-primary/5 px-4 py-2.5">
			<div class="min-w-0 flex-1">
				<p class="truncate text-xs font-bold text-primary">{fileName}</p>
				<p class="text-[11px] text-slate-500 dark:text-slate-400">
					{entries.length} Clippings aus {bookCount} B&uuml;chern
				</p>
			</div>
			<button
				onclick={reset}
				class="shrink-0 rounded-lg px-3 py-1.5 text-[11px] font-medium text-slate-500 hover:bg-white hover:text-slate-700 dark:text-slate-400 dark:hover:bg-white/5"
			>
				Andere Datei
			</button>
		</div>

		<!-- Filter chips -->
		<div class="mt-4 flex gap-2">
			{#each [
				{ k: 'all' as Filter, label: `Alle (${entries.length})` },
				{ k: 'short' as Filter, label: `Kurz \u2264 5 W. (${entries.filter((e) => wordCount(e.text) <= 5).length})` },
				{ k: 'long' as Filter, label: `Lang (${entries.filter((e) => wordCount(e.text) > 5).length})` },
			] as opt (opt.k)}
				<button
					onclick={() => (filter = opt.k)}
					class="flex h-8 shrink-0 items-center rounded-full px-4 text-xs font-semibold transition-colors {filter ===
					opt.k
						? 'bg-primary text-white'
						: 'bg-slate-100 text-slate-600 dark:bg-white/10 dark:text-slate-300'}"
				>
					{opt.label}
				</button>
			{/each}
		</div>

		<!-- Select-all toggle + counts -->
		<div class="mt-4 flex items-center justify-between">
			<button
				onclick={toggleAllVisible}
				class="text-[11px] font-bold uppercase tracking-wider text-primary hover:underline"
			>
				{allVisibleSelected ? 'Alle abw&auml;hlen' : 'Alle ausw&auml;hlen'}
			</button>
			<p class="text-[11px] text-slate-500 dark:text-slate-400">
				{selectedCount} / {entries.length} ausgew&auml;hlt
			</p>
		</div>

		<!-- Clipping list -->
		<ul class="mt-3 space-y-2">
			{#each filtered as { e, i } (i)}
				<li>
					<label
						class="flex cursor-pointer gap-3 rounded-xl border p-3 transition-colors {selected.has(
							i,
						)
							? 'border-primary/30 bg-primary/5'
							: 'border-slate-100 bg-white hover:bg-slate-50 dark:border-white/5 dark:bg-white/5 dark:hover:bg-white/10'}"
					>
						<input
							type="checkbox"
							checked={selected.has(i)}
							onchange={() => toggleEntry(i)}
							class="mt-0.5 size-4 shrink-0 cursor-pointer accent-primary"
						/>
						<div class="min-w-0 flex-1">
							<p class="break-words text-sm text-slate-800 dark:text-slate-200">{e.text}</p>
							<div class="mt-1.5 flex items-center gap-2 text-[10px] text-slate-400 dark:text-slate-500">
								<Book2 class="text-[11px]" />
								<span class="truncate">{e.book}{e.author ? ` — ${e.author}` : ''}</span>
								<span
									class="ml-auto shrink-0 rounded bg-slate-100 px-1.5 py-0.5 font-mono dark:bg-white/10"
									>{wordCount(e.text)} W.</span
								>
							</div>
						</div>
					</label>
				</li>
			{/each}
		</ul>

		<!-- Sticky bottom action bar — sits at the bottom of the scroll area
		     inside <main>. Negative -mx bleeds it out to the edge of the
		     column so the border reaches the sides, without needing any
		     fixed-position math. On mobile the (app) <main> has pb-24 so the
		     bar never overlaps the bottom tab nav. -->
		<div
			class="sticky bottom-0 z-10 -mx-4 mt-4 border-t border-primary/10 bg-bg-light/90 px-4 py-3 backdrop-blur-md dark:bg-bg-dark/90 lg:-mx-8 lg:px-8"
		>
			{#if importing}
				<button
					disabled
					class="flex w-full items-center justify-center gap-2 rounded-xl bg-primary/60 py-3 text-sm font-bold text-white"
				>
					<svg class="size-4 animate-spin" viewBox="0 0 24 24" fill="none">
						<circle cx="12" cy="12" r="10" stroke="currentColor" stroke-width="3" opacity="0.25" />
						<path
							d="M12 2a10 10 0 0 1 10 10"
							stroke="currentColor"
							stroke-width="3"
							stroke-linecap="round"
						/>
					</svg>
					Importiere {selectedCount} W&ouml;rter&hellip;
				</button>
			{:else}
				<button
					onclick={doImport}
					disabled={selectedCount === 0}
					class="flex w-full items-center justify-center gap-2 rounded-xl bg-primary py-3 text-sm font-bold text-white shadow-sm transition-colors hover:bg-primary/90 disabled:cursor-not-allowed disabled:opacity-50"
				>
					<Check class="text-[18px]" />
					Importieren ({selectedCount})
				</button>
			{/if}
		</div>
	{/if}
</div>
