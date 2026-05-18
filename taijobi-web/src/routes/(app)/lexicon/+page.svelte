<script lang="ts">
	import Add from '$lib/icons/Add.svelte';
	import Book2 from '$lib/icons/Book2.svelte';
	import Check from '$lib/icons/Check.svelte';
	import Close from '$lib/icons/Close.svelte';
	import Delete from '$lib/icons/Delete.svelte';
	import Edit from '$lib/icons/Edit.svelte';
	import Search from '$lib/icons/Search.svelte';
	import { goto } from '$app/navigation';
	import { page } from '$app/state';
	import { addWord, removeWord, restoreWord, updateWord, lookupWord, type LexiconEntry, type DictResult } from '$lib/wasm';
	import WiktEntry from '../../../components/WiktEntry.svelte';
	import { data } from '$lib/data.svelte';
	import { toastStore } from '$lib/toast.svelte';

	let adding = $state(false);
	let filter = $state('all');
	let editingId = $state<string | null>(null);
	let editTranslation = $state('');
	// Inline dictionary panel — at most one row expanded at a time. Lookup is
	// done once on expand (WASM binary search is sub-millisecond, so caching
	// across collapse/expand cycles isn't worth the bookkeeping). Only the
	// exact-match dictionary entry is shown; prefix matches would just be
	// noise here since the user already chose this exact word.
	let expandedId = $state<string | null>(null);
	let expandedHit = $state<DictResult | null>(null);
	// Single input does double duty: live-filters the list while the user
	// types, and adds the trimmed query as a new lexicon word on Enter / via
	// the + button (only when there's no exact match — find-or-create).
	// Initialised from ?q=… so the command palette can deep-link.
	let searchQuery = $state(page.url.searchParams.get('q') ?? '');

	$effect(() => {
		const current = page.url.searchParams.get('q') ?? '';
		if (current === searchQuery) return;
		const next = new URL(page.url);
		if (searchQuery.trim()) next.searchParams.set('q', searchQuery.trim());
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
		if (editingId === entry.id) return; // never toggle while editing the row
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

<!-- Combined search + add input.
     Type to filter · Enter (or +) to add the trimmed query · disabled when
     the word is already in the lexicon. Styling matches /characters and
     /dictionary so the search bar feels consistent across the app. -->
<section class="mt-4 flex items-center gap-2">
	<div
		class="flex h-12 min-w-0 flex-1 items-center gap-2 overflow-hidden rounded-xl border border-primary/10 bg-primary/5 px-4 transition-all focus-within:border-primary/30"
	>
		<Search class="shrink-0 text-[20px] text-primary/40" />
		<input
			type="search"
			bind:value={searchQuery}
			onkeydown={handleKeydown}
			placeholder="Suchen oder hinzuf&uuml;gen..."
			class="min-w-0 flex-1 border-none bg-transparent p-0 text-base font-normal outline-none placeholder:text-primary/40 focus:ring-0"
		/>
		{#if searchQuery}
			<button
				type="button"
				onclick={() => (searchQuery = '')}
				class="shrink-0 rounded-full p-1 text-primary/50 transition-colors hover:bg-primary/10 hover:text-primary"
				aria-label="Eingabe l&ouml;schen"
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
		aria-label="Hinzuf&uuml;gen"
		class="flex size-12 shrink-0 items-center justify-center rounded-xl bg-primary text-white shadow-sm transition-colors hover:bg-primary/90 disabled:opacity-40"
	>
		<Add />
	</button>
	</section>

{#if searchQuery.trim() && !exactMatch && !adding}
	<p class="mt-1.5 px-1 text-[11px] text-slate-400 dark:text-slate-500">
		Enter dr&uuml;cken oder + tippen, um &laquo;{searchQuery.trim()}&raquo; hinzuzuf&uuml;gen.
	</p>
{/if}

<!-- Filter Chips -->
<section class="mt-4 flex gap-2 overflow-x-auto no-scrollbar">
	<button
		onclick={() => (filter = 'all')}
		class="flex h-9 shrink-0 items-center justify-center rounded-full px-5 text-sm font-semibold transition-colors {filter === 'all'
			? 'bg-primary text-white'
			: 'bg-slate-100 text-slate-600 dark:bg-white/10 dark:text-slate-300'}"
	>
		Alle
	</button>
	<button
		onclick={() => (filter = 'zh')}
		class="flex h-9 shrink-0 items-center justify-center rounded-full px-5 text-sm font-medium transition-colors {filter === 'zh'
			? 'bg-primary text-white'
			: 'bg-slate-100 text-slate-600 dark:bg-white/10 dark:text-slate-300'}"
	>
		中文
	</button>
	<button
		onclick={() => (filter = 'de')}
		class="flex h-9 shrink-0 items-center justify-center rounded-full px-5 text-sm font-medium transition-colors {filter === 'de'
			? 'bg-primary text-white'
			: 'bg-slate-100 text-slate-600 dark:bg-white/10 dark:text-slate-300'}"
	>
		Deutsch
	</button>
	<button
		onclick={() => (filter = 'en')}
		class="flex h-9 shrink-0 items-center justify-center rounded-full px-5 text-sm font-medium transition-colors {filter === 'en'
			? 'bg-primary text-white'
			: 'bg-slate-100 text-slate-600 dark:bg-white/10 dark:text-slate-300'}"
	>
		English
	</button>
</section>

<!-- Word List -->
<section class="mt-6 space-y-6">
	{#if filtered.length === 0}
		<div class="rounded-2xl border border-slate-100 bg-white p-8 text-center shadow-sm dark:border-white/5 dark:bg-white/5">
			<Book2 class="mx-auto mb-2 block text-[32px] text-slate-300 dark:text-slate-500" />
			{#if searchNeedle || filter !== 'all'}
				<p class="text-sm text-slate-500 dark:text-slate-400">
					Keine Treffer{#if searchNeedle} f&uuml;r &laquo;{searchQuery}&raquo;{/if}.
				</p>
			{:else}
				<p class="text-sm text-slate-500 dark:text-slate-400">
					Noch keine W&ouml;rter. F&uuml;ge W&ouml;rter hinzu, die dir beim Lesen begegnen.
				</p>
			{/if}
		</div>
	{:else}
		<!-- Word group -->
		<div>
			<h3 class="mb-3 px-1 text-[11px] font-bold uppercase tracking-wider text-primary">
				Lexikon ({filtered.length} W&ouml;rter)
			</h3>
			<div class="space-y-3">
				{#each filtered as entry (entry.id)}
					<div
						class="rounded-2xl border border-slate-100 bg-white p-4 shadow-sm dark:border-white/5 dark:bg-slate-800/40"
					>
						{#if editingId === entry.id}
							<!-- Edit mode -->
							<div class="flex items-center gap-2">
								<input
									type="text"
									bind:value={editTranslation}
									onkeydown={handleEditKeydown}
									placeholder="&Uuml;bersetzung..."
									class="min-w-0 flex-1 rounded-lg border border-primary/20 bg-primary/5 px-3 py-2 text-sm text-slate-900 placeholder-primary/40 outline-none focus:border-primary/40 dark:text-slate-100"
								/>
								<button
									onclick={saveEdit}
									class="rounded-lg bg-primary p-2 text-white transition-colors hover:bg-primary/90"
								>
									<Check class="text-[18px]" />
								</button>
								<button
									onclick={cancelEdit}
									class="rounded-lg bg-slate-100 p-2 text-slate-500 transition-colors hover:bg-slate-200 dark:bg-white/10 dark:text-slate-400 dark:hover:bg-white/15"
								>
									<Close class="text-[18px]" />
								</button>
							</div>
						{:else}
							<!-- Display mode: tap the word/translation area to expand the
							     full Wiktionary entry inline; action buttons + CJK char
							     links handle their own click via stopPropagation. -->
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
											>{entry.word}</a>
										{:else if entry.language === 'ar'}
											<span dir="rtl" class="text-xl font-bold text-slate-900 dark:text-slate-100">{entry.word}</span>
										{:else}
											<span class="text-lg font-bold text-slate-900 dark:text-slate-100">{entry.word}</span>
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
											{#if entry.translation} &bull; {/if}
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
									<button
										onclick={(e) => { e.stopPropagation(); startEdit(entry); }}
										class="rounded-lg p-1.5 text-slate-300 transition-colors hover:bg-slate-100 hover:text-primary dark:text-slate-500 dark:hover:bg-white/10 dark:hover:text-primary"
										title="Bearbeiten"
									>
										<Edit class="text-[18px]" />
									</button>
									<button
										onclick={(e) => { e.stopPropagation(); handleRemove(entry); }}
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
											Kein W&ouml;rterbuch-Eintrag f&uuml;r &laquo;{entry.word}&raquo; gefunden.
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
</section>
