<script lang="ts">
	import Add from '$lib/icons/Add.svelte';
	import AddCircle from '$lib/icons/AddCircle.svelte';
	import Book2 from '$lib/icons/Book2.svelte';
	import CheckCircle from '$lib/icons/CheckCircle.svelte';
	import Close from '$lib/icons/Close.svelte';
	import Delete from '$lib/icons/Delete.svelte';
	import Edit from '$lib/icons/Edit.svelte';
	import HourglassEmpty from '$lib/icons/HourglassEmpty.svelte';
	import Search from '$lib/icons/Search.svelte';
	import VolumeUp from '$lib/icons/VolumeUp.svelte';
	import { goto } from '$app/navigation';
	import { page } from '$app/state';
	import {
		addWord,
		removeWord,
		restoreWord,
		updateWord,
		lookupWord,
		lookupCedict,
		type CedictResult,
		type LexiconEntry,
		type DictResult,
	} from '$lib/wasm';
	import WiktEntry from '../../../components/WiktEntry.svelte';
	import { speak, canSpeak } from '$lib/speak';
	import { data } from '$lib/data.svelte';
	import { toastStore } from '$lib/toast.svelte';

	type DictHit =
		| { type: 'cedict'; word: string; pinyin: string; definition: string; entry: CedictResult }
		| { type: 'wikt'; word: string; entry: DictResult };

	let adding = $state(false);
	let busyWord = $state<string | null>(null);
	let filter = $state('all');
	let editingId = $state<string | null>(null);
	let editTranslation = $state('');
	// Inline definition panel — one expanded lexicon row at a time.
	let expandedId = $state<string | null>(null);
	let expandedHit = $state<DictResult | null>(null);
	// One input does triple duty: filter lexicon · search dictionary · add new
	// word on Enter (when no exact lexicon match exists).
	let searchQuery = $state(page.url.searchParams.get('q') ?? '');
	let dictHits: DictHit[] = $state([]);
	let debounceTimer: ReturnType<typeof setTimeout> | undefined;

	// Compare against the *trimmed* query — that's what actually lands in the
	// URL. Comparing the raw input instead never converges when it has
	// leading/trailing whitespace (Gboard appends a space when you tap a
	// suggestion): the guard stays false, goto reassigns page.url, the effect
	// re-runs, and the app spins in an endless navigation loop.
	$effect(() => {
		const trimmed = searchQuery.trim();
		const current = page.url.searchParams.get('q') ?? '';
		if (current === trimmed) return;
		const next = new URL(page.url);
		if (trimmed) next.searchParams.set('q', trimmed);
		else next.searchParams.delete('q');
		goto(next.pathname + next.search, { replaceState: true, keepFocus: true, noScroll: true });
	});

	let entries: LexiconEntry[] = $derived(data.lexicon());

	let searchNeedle = $derived(searchQuery.trim().toLowerCase());

	let exactMatch = $derived(
		searchNeedle ? entries.some((e) => e.word.toLowerCase() === searchNeedle) : false,
	);

	let filtered = $derived.by(() => {
		const byLang = filter === 'all' ? entries : entries.filter((e) => e.language === filter);
		if (!searchNeedle) return byLang;
		return byLang.filter((e) => {
			const w = e.word.toLowerCase();
			const t = (e.translation ?? '').toLowerCase();
			const p = (e.pinyin ?? '').toLowerCase();
			return w.includes(searchNeedle) || t.includes(searchNeedle) || p.includes(searchNeedle);
		});
	});

	let lexiconMap = $derived(new Map(entries.map((e) => [e.word, e.id])));

	function hasChinese(text: string): boolean {
		return [...text].some((ch) => {
			const code = ch.codePointAt(0) ?? 0;
			return (code >= 0x4e00 && code <= 0x9fff) || (code >= 0x3400 && code <= 0x4dbf);
		});
	}

	function splitChars(text: string): string[] {
		return [...text].filter((ch) => ch.charCodeAt(0) > 0x2e80);
	}

	// Debounced dictionary lookup — runs whenever the query changes. Only
	// matters when something is typed; empty query clears the list.
	$effect(() => {
		const q = searchQuery.trim();
		clearTimeout(debounceTimer);
		if (!q) {
			dictHits = [];
			return;
		}
		debounceTimer = setTimeout(() => {
			const unified: DictHit[] = [];
			if (hasChinese(q)) {
				for (const r of lookupCedict(q).slice(0, 8)) {
					unified.push({
						type: 'cedict',
						word: r.simplified,
						pinyin: r.pinyin,
						definition: r.english,
						entry: r,
					});
				}
			}
			for (const r of lookupWord(q).slice(0, 8)) {
				unified.push({ type: 'wikt', word: r.word, entry: r });
			}
			// Fall back to CEDICT for non-CJK queries (pinyin/English) when the
			// Wiktionary search returned nothing.
			if (!hasChinese(q) && unified.length === 0) {
				for (const r of lookupCedict(q).slice(0, 8)) {
					unified.push({
						type: 'cedict',
						word: r.simplified,
						pinyin: r.pinyin,
						definition: r.english,
						entry: r,
					});
				}
			}
			// Drop entries that already exist as a lexicon row matching the
			// current filter — they're already visible above with full edit
			// controls; showing them again as bare dictionary hits would be
			// redundant.
			dictHits = unified.filter((h) => !filtered.some((e) => e.word === h.word));
		}, 150);
	});

	async function handleAdd() {
		const word = searchQuery.trim();
		if (!word || adding || exactMatch) return;
		adding = true;
		try {
			const result = await addWord(word);
			searchQuery = '';
			const tail = result.translation
				? ` — ${result.translation}`
				: result.pinyin
					? ` — ${result.pinyin}`
					: '';
			toastStore.show(`«${result.word}» [${result.language}]${tail}`);
		} catch (e) {
			const msg = e instanceof Error ? e.message : 'Wort konnte nicht hinzugefügt werden';
			toastStore.show(msg.includes('already') ? `«${word}» ist bereits im Lexikon` : msg);
		} finally {
			adding = false;
		}
	}

	function handleKeydown(e: KeyboardEvent) {
		if (e.key === 'Enter' && !exactMatch) handleAdd();
	}

	async function handleRemove(entry: LexiconEntry) {
		try {
			await removeWord(entry.id);
			toastStore.show(`«${entry.word}» entfernt`, async () => {
				await restoreWord(entry.id);
				toastStore.show(`«${entry.word}» wiederhergestellt`);
			});
		} catch (e) {
			toastStore.show(e instanceof Error ? e.message : 'Entfernen fehlgeschlagen');
		}
	}

	async function handleDictToggle(word: string) {
		if (busyWord) return;
		busyWord = word;
		try {
			const existingId = lexiconMap.get(word);
			if (existingId) {
				await removeWord(existingId);
				toastStore.show(`«${word}» entfernt`);
			} else {
				await addWord(word);
				toastStore.show(`«${word}» zum Lexikon hinzugefügt`);
			}
		} catch (e) {
			const msg = e instanceof Error ? e.message : 'Fehler';
			toastStore.show(msg.includes('already') ? `«${word}» ist bereits im Lexikon` : msg);
			data.bump();
		} finally {
			busyWord = null;
		}
	}

	function startEdit(entry: LexiconEntry) {
		editingId = entry.id;
		editTranslation = entry.translation ?? '';
	}

	function cancelEdit() {
		editingId = null;
		editTranslation = '';
	}

	async function saveEdit() {
		if (!editingId) return;
		try {
			await updateWord(editingId, editTranslation);
			editingId = null;
			editTranslation = '';
		} catch (e) {
			toastStore.show(e instanceof Error ? e.message : 'Aktualisieren fehlgeschlagen');
		}
	}

	function handleEditKeydown(e: KeyboardEvent) {
		if (e.key === 'Enter') saveEdit();
		if (e.key === 'Escape') cancelEdit();
	}

	function toggleExpand(entry: LexiconEntry) {
		if (editingId === entry.id) return;
		if (expandedId === entry.id) {
			expandedId = null;
			expandedHit = null;
			return;
		}
		const needle = entry.word.toLowerCase();
		const hits = lookupWord(entry.word);
		expandedHit = hits.find((h) => h.word.toLowerCase() === needle) ?? null;
		expandedId = entry.id;
	}

	function handleRowKeydown(e: KeyboardEvent, entry: LexiconEntry) {
		if (e.key === 'Enter' || e.key === ' ') {
			e.preventDefault();
			toggleExpand(entry);
		}
	}

	function langTag(code: string): string {
		switch (code) {
			case 'zh':
				return 'ZH';
			case 'de':
				return 'DE';
			case 'en':
				return 'EN';
			default:
				return code.toUpperCase();
		}
	}

	function statusColor(entry: LexiconEntry): string {
		if (entry.reps === 0) return 'bg-slate-300';
		if (entry.stability > 5) return 'bg-[#2d6a4f]';
		return 'bg-amber-500';
	}

	function statusTitle(entry: LexiconEntry): string {
		if (entry.reps === 0) return 'Neu';
		if (entry.stability > 5) return 'Gelernt';
		return 'Wiederholen';
	}
</script>

<!-- Combined search + add input — type to filter lexicon AND search the
     dictionary; Enter (or +) adds the trimmed query as a new lexicon word
     when it isn't already saved. -->
<section class="mt-4 flex items-center gap-2">
	<div
		class="flex h-12 min-w-0 flex-1 items-center gap-2 overflow-hidden rounded-xl border border-primary/10 bg-primary/5 px-4 transition-all focus-within:border-primary/30"
	>
		<Search class="shrink-0 text-[20px] text-primary/40" />
		<input
			type="text"
			bind:value={searchQuery}
			onkeydown={handleKeydown}
			placeholder="Suchen oder hinzufügen..."
			class="min-w-0 flex-1 border-none bg-transparent p-0 text-base font-normal outline-none placeholder:text-primary/40 focus:ring-0"
		/>
		{#if searchQuery}
			<button
				type="button"
				onclick={() => (searchQuery = '')}
				class="shrink-0 rounded-full p-1 text-primary/50 transition-colors hover:bg-primary/10 hover:text-primary"
				aria-label="Eingabe löschen"
			>
				<Close class="text-[16px]" />
			</button>
		{/if}
	</div>
	<button
		onclick={handleAdd}
		disabled={adding || !searchQuery.trim() || exactMatch}
		title={exactMatch
			? 'Bereits im Lexikon'
			: searchQuery.trim()
				? `«${searchQuery.trim()}» hinzufügen`
				: 'Hinzufügen'}
		aria-label="Hinzufügen"
		class="flex size-12 shrink-0 items-center justify-center rounded-xl bg-primary text-white shadow-sm transition-colors hover:bg-primary/90 disabled:opacity-40"
	>
		<Add />
	</button>
</section>

{#if searchQuery.trim() && !exactMatch && !adding}
	<p class="mt-1.5 px-1 text-[11px] text-slate-400 dark:text-slate-500">
		Enter drücken oder + tippen, um «{searchQuery.trim()}» hinzuzufügen.
	</p>
{/if}

<!-- Filter Chips -->
<section class="mt-4 flex gap-2 overflow-x-auto no-scrollbar">
	{#each [
		['all', 'Alle'],
		['zh', '中文'],
		['de', 'Deutsch'],
		['en', 'English'],
	] as [k, label] (k)}
		<button
			onclick={() => (filter = k)}
			class="flex h-9 shrink-0 items-center justify-center rounded-full px-5 text-sm font-medium transition-colors {filter === k
				? 'bg-primary text-white'
				: 'bg-slate-100 text-slate-600 dark:bg-white/10 dark:text-slate-300'}"
		>
			{label}
		</button>
	{/each}
</section>

<!-- Lexicon list -->
<section class="mt-6 space-y-6">
	{#if filtered.length === 0 && !searchNeedle}
		<div
			class="rounded-2xl border border-slate-100 bg-white p-8 text-center shadow-sm dark:border-white/5 dark:bg-white/5"
		>
			<Book2 class="mx-auto mb-2 block text-[32px] text-slate-300 dark:text-slate-500" />
			<p class="text-sm text-slate-500 dark:text-slate-400">
				Noch keine Wörter. Füge Wörter hinzu, die dir beim Lesen begegnen.
			</p>
		</div>
	{:else if filtered.length > 0}
		<div>
			<h3 class="mb-3 px-1 text-[11px] font-bold uppercase tracking-wider text-primary">
				Lexikon ({filtered.length} {filtered.length === 1 ? 'Wort' : 'Wörter'})
			</h3>
			<div class="space-y-3">
				{#each filtered as entry (entry.id)}
					<div
						class="rounded-2xl border border-slate-100 bg-white p-4 shadow-sm dark:border-white/5 dark:bg-slate-800/40"
					>
						{#if editingId === entry.id}
							<div class="flex items-center gap-2">
								<input
									type="text"
									bind:value={editTranslation}
									onkeydown={handleEditKeydown}
									placeholder="Übersetzung..."
									class="min-w-0 flex-1 rounded-lg border border-primary/20 bg-primary/5 px-3 py-2 text-sm text-slate-900 placeholder-primary/40 outline-none focus:border-primary/40 dark:text-slate-100"
								/>
								<button
									onclick={saveEdit}
									class="rounded-lg bg-primary p-2 text-white transition-colors hover:bg-primary/90"
								>
									<CheckCircle class="text-[18px]" />
								</button>
								<button
									onclick={cancelEdit}
									class="rounded-lg bg-slate-100 p-2 text-slate-500 transition-colors hover:bg-slate-200 dark:bg-white/10 dark:text-slate-400 dark:hover:bg-white/15"
								>
									<Close class="text-[18px]" />
								</button>
							</div>
						{:else}
							<div class="flex items-center">
								<div
									role="button"
									tabindex="0"
									aria-expanded={expandedId === entry.id}
									onclick={() => toggleExpand(entry)}
									onkeydown={(e) => handleRowKeydown(e, entry)}
									class="min-w-0 flex-1 cursor-pointer rounded-lg outline-none focus-visible:ring-2 focus-visible:ring-primary/40"
								>
									<div class="mb-0.5 flex items-center gap-2">
										{#if entry.language === 'zh'}
											<a
												href="/character/{encodeURIComponent(entry.word)}"
												onclick={(e) => e.stopPropagation()}
												class="chinese-char text-lg font-bold text-slate-900 hover:text-primary dark:text-slate-100"
												>{entry.word}</a
											>
										{:else if entry.language === 'ar'}
											<span dir="rtl" class="text-xl font-bold text-slate-900 dark:text-slate-100"
												>{entry.word}</span
											>
										{:else}
											<span class="text-lg font-bold text-slate-900 dark:text-slate-100"
												>{entry.word}</span
											>
										{/if}
										<span
											class="rounded bg-primary/5 px-1.5 py-0.5 text-[10px] font-bold text-primary"
										>
											{langTag(entry.language)}
										</span>
									</div>
									<p class="text-[13px] text-slate-500 dark:text-slate-400">
										{#if entry.pinyin}
											{entry.pinyin}
											{#if entry.translation} • {/if}
										{/if}
										{#if entry.translation}
											{entry.translation}
										{:else if entry.reps === 0}
											Neu
										{:else}
											{entry.reps} Wiederholungen
										{/if}
									</p>
								</div>
								<div class="flex items-center gap-1">
									{#if canSpeak()}
										<button
											onclick={(e) => {
												e.stopPropagation();
												speak(entry.word, entry.language || 'auto');
											}}
											class="rounded-lg p-1.5 text-slate-300 transition-colors hover:bg-slate-100 hover:text-primary dark:text-slate-500 dark:hover:bg-white/10 dark:hover:text-primary"
											title="Aussprechen"
										>
											<VolumeUp class="text-[18px]" />
										</button>
									{/if}
									<button
										onclick={(e) => {
											e.stopPropagation();
											startEdit(entry);
										}}
										class="rounded-lg p-1.5 text-slate-300 transition-colors hover:bg-slate-100 hover:text-primary dark:text-slate-500 dark:hover:bg-white/10 dark:hover:text-primary"
										title="Bearbeiten"
									>
										<Edit class="text-[18px]" />
									</button>
									<button
										onclick={(e) => {
											e.stopPropagation();
											handleRemove(entry);
										}}
										class="rounded-lg p-1.5 text-slate-300 transition-colors hover:bg-red-50 hover:text-red-600 dark:text-slate-500 dark:hover:bg-red-950"
										title="Entfernen"
									>
										<Delete class="text-[18px]" />
									</button>
									<div
										class="ml-1 size-2.5 rounded-full {statusColor(entry)}"
										title={statusTitle(entry)}
									></div>
								</div>
							</div>

							{#if expandedId === entry.id}
								<div class="mt-3 border-t border-slate-100 pt-3 dark:border-white/5">
									{#if !expandedHit}
										<p class="text-[13px] italic text-slate-400 dark:text-slate-500">
											Kein Wörterbuch-Eintrag für «{entry.word}» gefunden.
										</p>
									{:else}
										<WiktEntry result={expandedHit} />
									{/if}
								</div>
							{/if}
						{/if}
					</div>
				{/each}
			</div>
		</div>
	{/if}

	<!-- Dictionary hits — only when actively searching and not editing. -->
	{#if searchNeedle && dictHits.length > 0}
		<div>
			<h3 class="mb-3 px-1 text-[11px] font-bold uppercase tracking-wider text-primary">
				Wörterbuch ({dictHits.length})
			</h3>
			<div class="space-y-3">
				{#each dictHits as hit, i (hit.word + i)}
					<div
						class="rounded-2xl border border-slate-100 bg-white p-4 shadow-sm dark:border-white/5 dark:bg-slate-800/40"
					>
						<div class="flex items-start gap-3">
							<div class="min-w-0 flex-1">
								<div class="mb-2 flex flex-wrap items-baseline gap-2">
									{#if hit.type === 'cedict'}
										<span class="text-2xl font-light">
											{#each splitChars(hit.word) as char (char)}
												<a
													href="/character/{encodeURIComponent(char)}"
													class="chinese-char hover:text-primary">{char}</a
												>
											{/each}
											{#if splitChars(hit.word).length === 0}
												<span>{hit.word}</span>
											{/if}
										</span>
										<span class="text-sm text-primary/70 dark:text-accent">{hit.pinyin}</span>
									{:else}
										<span class="text-xl font-semibold text-slate-900 dark:text-slate-100"
											>{hit.word}</span
										>
									{/if}
								</div>

								{#if hit.type === 'cedict'}
									<p class="text-[13px] leading-relaxed text-slate-600 dark:text-slate-400">
										{hit.definition}
									</p>
								{:else}
									<WiktEntry result={hit.entry} />
								{/if}
							</div>

							<div class="flex shrink-0 items-center gap-1">
								<button
									onclick={() => speak(hit.word, hit.type === 'cedict' ? 'zh' : 'auto')}
									class="rounded-lg p-1.5 text-slate-300 transition-colors hover:bg-slate-100 hover:text-primary dark:text-slate-500 dark:hover:bg-white/10"
									title="Aussprechen"
								>
									<VolumeUp class="text-[20px]" />
								</button>
								<button
									onclick={() => handleDictToggle(hit.word)}
									disabled={busyWord === hit.word}
									class="rounded-lg p-1.5 transition-colors disabled:opacity-50 {lexiconMap.has(
										hit.word,
									)
										? 'text-primary hover:bg-red-50 hover:text-red-500 dark:hover:bg-red-950'
										: 'text-slate-300 hover:bg-primary/10 hover:text-primary dark:text-slate-500 dark:hover:bg-primary/20'}"
									title={lexiconMap.has(hit.word)
										? 'Aus Lexikon entfernen'
										: 'Zum Lexikon hinzufügen'}
								>
									{#if busyWord === hit.word}
										<HourglassEmpty class="text-[20px]" />
									{:else if lexiconMap.has(hit.word)}
										<CheckCircle class="text-[20px]" />
									{:else}
										<AddCircle class="text-[20px]" />
									{/if}
								</button>
							</div>
						</div>
					</div>
				{/each}
			</div>
		</div>
	{/if}

	{#if searchNeedle && filtered.length === 0 && dictHits.length === 0}
		<div
			class="rounded-2xl border border-slate-100 bg-white p-8 text-center shadow-sm dark:border-white/5 dark:bg-white/5"
		>
			<Search class="mx-auto mb-2 block text-[32px] text-slate-300 dark:text-slate-500" />
			<p class="text-sm text-slate-500 dark:text-slate-400">
				Keine Treffer für «{searchQuery}». Enter drücken, um es trotzdem zu speichern.
			</p>
		</div>
	{/if}
</section>
