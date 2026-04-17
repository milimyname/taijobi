<script lang="ts">
	import { goto } from '$app/navigation';
	import Drawer from './Drawer.svelte';
	import Search from '$lib/icons/Search.svelte';
	import Close from '$lib/icons/Close.svelte';
	import Today from '$lib/icons/Today.svelte';
	import Add from '$lib/icons/Add.svelte';
	import PlayArrow from '$lib/icons/PlayArrow.svelte';
	import PlayCircle from '$lib/icons/PlayCircle.svelte';
	import Inventory2 from '$lib/icons/Inventory2.svelte';
	import Dictionary from '$lib/icons/Dictionary.svelte';
	import { paletteStore } from '$lib/commandPalette.svelte';
	import {
		searchCards,
		lookupCedict,
		lookupWord,
		addWord,
		type CardSearchResult,
		type CedictResult,
		type DictResult
	} from '$lib/wasm';
	import { searchIndex, type PinyinHit } from '$lib/searchIndex.svelte';
	import { getActions, type PaletteAction } from '$lib/actions.svelte';
	import {
		catalogStore,
		tagLabel,
		tagBadgeClass,
		type CatalogEntry
	} from '$lib/catalog-store.svelte';
	import { recentCharsStore } from '$lib/recent-chars.svelte';
	import { data } from '$lib/data.svelte';
	import { LS_SEARCH_HISTORY } from '$lib/config';
	import { toastStore } from '$lib/toast.svelte';

	const MAX_HISTORY = 5;

	let query = $state('');
	let selectedIndex = $state(0);
	let inputRef = $state<HTMLInputElement | undefined>();
	let listRef: HTMLDivElement | undefined = $state();
	let cardResults = $state<CardSearchResult[]>([]);
	let pinyinResults = $state<PinyinHit[]>([]);
	let dictResults = $state<CedictResult[]>([]);
	let wiktResults = $state<DictResult[]>([]);
	let recent = $state<string[]>(loadRecent());
	let adding = $state(false);
	let debounceHandle: ReturnType<typeof setTimeout> | null = null;

	function loadRecent(): string[] {
		try {
			const raw = localStorage.getItem(LS_SEARCH_HISTORY);
			if (!raw) return [];
			const parsed = JSON.parse(raw);
			if (Array.isArray(parsed)) return parsed.filter((x) => typeof x === 'string');
			return [];
		} catch {
			return [];
		}
	}

	function saveRecent(q: string): void {
		if (q.length < 2) return;
		const next = [q, ...recent.filter((r) => r !== q)].slice(0, MAX_HISTORY);
		recent = next;
		try {
			localStorage.setItem(LS_SEARCH_HISTORY, JSON.stringify(next));
		} catch {
			/* ignore */
		}
	}

	function isSingleHanzi(s: string): boolean {
		if (!s) return false;
		const arr = Array.from(s);
		if (arr.length !== 1) return false;
		const cp = arr[0].codePointAt(0) ?? 0;
		return cp >= 0x4e00 && cp <= 0x9fff;
	}

	function hasChinese(s: string): boolean {
		for (const ch of s) {
			const cp = ch.codePointAt(0) ?? 0;
			if (cp >= 0x4e00 && cp <= 0x9fff) return true;
		}
		return false;
	}

	// Build a /lessons/{pack} URL with optional ?lesson=&card= for deep-link
	// scroll + highlight on the target row.
	function buildLessonUrl(packId: string, lessonId: string | null, cardId: string): string {
		const params = new URLSearchParams();
		if (lessonId) params.set('lesson', lessonId);
		if (cardId) params.set('card', cardId);
		const qs = params.toString();
		return `/lessons/${encodeURIComponent(packId)}${qs ? `?${qs}` : ''}`;
	}

	// ----- Query parsing: prefixes + modes -----
	// `drill ` / `üben `  → drill launcher mode (suppress everything else)
	// `book:X` / `quelle:X` / `from:X`  → filter cards by context column
	const DRILL_RE = /^(drill|üben)\s+(.*)$/i;
	const BOOK_RE = /^(book|quelle|from):(\S+)\s*(.*)$/i;

	const drillMatch = $derived(query.match(DRILL_RE));
	const bookMatch = $derived(query.match(BOOK_RE));
	const isDrillMode = $derived(drillMatch !== null);
	const drillQuery = $derived(drillMatch ? drillMatch[2].trim() : '');
	const bookFilter = $derived(bookMatch ? bookMatch[2] : '');
	const bookRest = $derived(bookMatch ? bookMatch[3].trim() : '');
	// The "effective" query passed to searchCards when book: is active.
	const searchQuery = $derived(bookMatch ? bookRest || bookFilter : query.trim());

	const filteredActions = $derived.by(() => {
		// Drill launcher mode owns the results — don't clutter with actions.
		if (isDrillMode) return [] as PaletteAction[];
		const q = query.trim().toLowerCase();
		const all = getActions().filter((a) => (a.enabled ? a.enabled() : true));
		const dangerVisible = /reset|löschen|loschen|danger/i.test(q);
		const filtered = all.filter((a) => {
			if (a.group === 'Danger Zone' && !dangerVisible) return false;
			if (!q) return a.group !== 'Danger Zone';
			return (
				a.label.toLowerCase().includes(q) ||
				a.keywords.some((k) => k.includes(q)) ||
				a.group.toLowerCase().includes(q)
			);
		});
		return filtered;
	});

	// ----- Pack search -----
	const packResults = $derived.by<CatalogEntry[]>(() => {
		if (isDrillMode || bookMatch) return [];
		const q = query.trim().toLowerCase();
		if (!q) return [];
		return catalogStore.entries
			.filter((e) => {
				const hay = `${e.name} ${e.description} ${e.language_pair} ${e.id}`.toLowerCase();
				return hay.includes(q);
			})
			.slice(0, 5);
	});

	// ----- Drill launcher: content packs matching the rest-query -----
	const drillPacks = $derived.by<CatalogEntry[]>(() => {
		if (!isDrillMode) return [];
		const q = drillQuery.toLowerCase();
		return catalogStore.entries
			.filter((e) => e.kind === 'content')
			.filter((e) => {
				if (!q) return true;
				const hay = `${e.name} ${e.id}`.toLowerCase();
				return hay.includes(q);
			})
			.slice(0, 5);
	});

	// ----- Last reviewed card (empty state only) -----
	const lastReviewed = $derived(query.trim() === '' ? data.lastReviewedCard() : null);

	// ----- Recent characters (empty state only) -----
	const recentChars = $derived(query.trim() === '' ? recentCharsStore.chars : []);

	// ----- Quick-add availability -----
	const quickAddAvailable = $derived(
		query.trim().length >= 1 &&
			query.trim().length <= 50 &&
			!isDrillMode &&
			!bookMatch &&
			!query.startsWith('>') &&
			cardResults.length === 0 &&
			pinyinResults.length === 0 &&
			dictResults.length === 0 &&
			wiktResults.length === 0 &&
			packResults.length === 0 &&
			!isSingleHanzi(query.trim())
	);

	const groupedActions = $derived.by(() => {
		const groups: Record<string, PaletteAction[]> = {};
		for (const a of filteredActions) {
			(groups[a.group] ??= []).push(a);
		}
		return groups;
	});

	const showRecent = $derived(query.trim() === '' && recent.length > 0);
	const singleHanziHit = $derived(isSingleHanzi(query.trim()));

	// Debounced async searches — use searchQuery (prefix-stripped) as input.
	$effect(() => {
		const q = searchQuery;
		const inDrill = isDrillMode;
		if (debounceHandle) clearTimeout(debounceHandle);
		if (!q || inDrill) {
			cardResults = [];
			pinyinResults = [];
			dictResults = [];
			wiktResults = [];
			return;
		}
		const currentBook = bookFilter;
		debounceHandle = setTimeout(() => {
			let cards = searchCards(q, 20);
			// Post-filter by context column when book: filter is active.
			if (currentBook) {
				const lowerBook = currentBook.toLowerCase();
				cards = cards.filter((c) => (c.context ?? '').toLowerCase().includes(lowerBook));
			}
			cardResults = cards.slice(0, 8);
			searchIndex
				.fuzzyPinyin(q, 8)
				.then((hits) => {
					const seen = new Set(cardResults.map((c) => c.id));
					pinyinResults = hits.filter((h) => !seen.has(h.id));
				})
				.catch(() => (pinyinResults = []));
			// CEDICT + Wiktionary lookups when book filter is off. Dict doubles
			// as a real dictionary: type any EN/DE word and ⌘K pulls the gloss.
			if (!currentBook) {
				if (data.chineseDataLoaded()) {
					dictResults = lookupCedict(q).slice(0, 5);
				} else {
					dictResults = [];
				}
				if (data.endictLoaded() || data.dedictLoaded()) {
					wiktResults = lookupWord(q).slice(0, 5);
				} else {
					wiktResults = [];
				}
			} else {
				dictResults = [];
				wiktResults = [];
			}
		}, 200);
	});

	// Ensure catalog is loaded when the palette opens (lazy).
	$effect(() => {
		if (paletteStore.open) void catalogStore.ensureLoaded();
	});

	// Flat item list for keyboard nav
	type FlatItem =
		| { kind: 'quickadd'; value: string }
		| { kind: 'last-reviewed'; value: CardSearchResult }
		| { kind: 'recent-char'; value: string }
		| { kind: 'recent'; value: string }
		| { kind: 'pack'; value: CatalogEntry }
		| { kind: 'drill-pack'; value: CatalogEntry }
		| { kind: 'action'; value: PaletteAction }
		| { kind: 'card'; value: CardSearchResult }
		| { kind: 'pinyin'; value: PinyinHit }
		| { kind: 'dict'; value: CedictResult }
		| { kind: 'wikt'; value: DictResult }
		| { kind: 'character'; value: string };

	const flatItems = $derived.by(() => {
		const items: FlatItem[] = [];
		// Empty-state sections
		if (lastReviewed) items.push({ kind: 'last-reviewed', value: lastReviewed });
		for (const ch of recentChars) items.push({ kind: 'recent-char', value: ch });
		if (showRecent) {
			for (const r of recent) items.push({ kind: 'recent', value: r });
		}
		// Query-driven sections
		if (quickAddAvailable) items.push({ kind: 'quickadd', value: query.trim() });
		for (const p of packResults) items.push({ kind: 'pack', value: p });
		for (const p of drillPacks) items.push({ kind: 'drill-pack', value: p });
		for (const group of Object.values(groupedActions)) {
			for (const a of group) items.push({ kind: 'action', value: a });
		}
		for (const c of cardResults) items.push({ kind: 'card', value: c });
		for (const p of pinyinResults) items.push({ kind: 'pinyin', value: p });
		for (const d of dictResults) items.push({ kind: 'dict', value: d });
		for (const w of wiktResults) items.push({ kind: 'wikt', value: w });
		if (singleHanziHit) items.push({ kind: 'character', value: query.trim() });
		return items;
	});

	$effect(() => {
		// Read flatItems to register it as a reactive dependency — whenever
		// the list changes (new query, new results), reset the highlight to
		// the first row.
		void flatItems;
		selectedIndex = 0;
	});

	$effect(() => {
		if (paletteStore.open) {
			// Delay so the Drawer animation has time to settle and the input
			// is mounted + visible before we focus it. queueMicrotask is too
			// fast — the input might not be rendered yet.
			setTimeout(() => inputRef?.focus(), 200);
		} else {
			query = '';
			selectedIndex = 0;
		}
	});

	function close(): void {
		paletteStore.hide();
	}

	async function executeItem(item: FlatItem): Promise<void> {
		if (item.kind === 'action') {
			close();
			try {
				await item.value.handler();
			} catch (e) {
				console.error(e);
				toastStore.show('Aktion fehlgeschlagen');
			}
			return;
		}
		if (item.kind === 'card') {
			saveRecent(query.trim());
			close();
			const c = item.value;
			if (c.language === 'zh' && isSingleHanzi(c.word)) {
				goto(`/character/${encodeURIComponent(c.word)}`);
			} else if (c.source_type === 'lexicon') {
				goto('/lexicon');
			} else if (c.pack_id) {
				goto(buildLessonUrl(c.pack_id, c.lesson_id, c.id));
			} else {
				goto('/lexicon');
			}
			return;
		}
		if (item.kind === 'pinyin') {
			saveRecent(query.trim());
			close();
			if (isSingleHanzi(item.value.word)) {
				goto(`/character/${encodeURIComponent(item.value.word)}`);
			} else {
				goto('/lexicon');
			}
			return;
		}
		if (item.kind === 'dict') {
			saveRecent(query.trim());
			close();
			if (hasChinese(item.value.simplified) && isSingleHanzi(item.value.simplified)) {
				goto(`/character/${encodeURIComponent(item.value.simplified)}`);
			} else {
				goto(`/dictionary?q=${encodeURIComponent(item.value.simplified)}`);
			}
			return;
		}
		if (item.kind === 'wikt') {
			saveRecent(query.trim());
			close();
			goto(`/dictionary?q=${encodeURIComponent(item.value.word)}`);
			return;
		}
		if (item.kind === 'character') {
			saveRecent(query.trim());
			close();
			goto(`/character/${encodeURIComponent(item.value)}`);
			return;
		}
		if (item.kind === 'recent') {
			query = item.value;
			inputRef?.focus();
			return;
		}
		if (item.kind === 'pack') {
			close();
			goto(`/packs#pack-${encodeURIComponent(item.value.id)}`);
			return;
		}
		if (item.kind === 'drill-pack') {
			close();
			goto(`/drill?pack=${encodeURIComponent(item.value.id)}`);
			return;
		}
		if (item.kind === 'recent-char') {
			close();
			goto(`/character/${encodeURIComponent(item.value)}`);
			return;
		}
		if (item.kind === 'last-reviewed') {
			close();
			const c = item.value;
			if (hasChinese(c.word) && isSingleHanzi(c.word)) {
				goto(`/character/${encodeURIComponent(c.word)}`);
			} else if (c.source_type === 'lexicon') {
				goto('/lexicon');
			} else if (c.pack_id) {
				goto(buildLessonUrl(c.pack_id, c.lesson_id, c.id));
			} else {
				goto('/lexicon');
			}
			return;
		}
		if (item.kind === 'quickadd') {
			if (adding) return;
			adding = true;
			try {
				const result = await addWord(item.value);
				data.bump();
				toastStore.show(`«${item.value}» hinzugefügt (${result.language})`);
				close();
			} catch (e) {
				const msg = e instanceof Error ? e.message : 'Fehler';
				toastStore.show(msg.includes('already') ? `«${item.value}» ist schon im Lexikon` : msg);
			} finally {
				adding = false;
			}
			return;
		}
	}

	function onKeydown(e: KeyboardEvent) {
		if (!paletteStore.open) return;
		if (e.key === 'Escape') {
			e.preventDefault();
			if (query) query = '';
			else close();
			return;
		}
		if (e.key === 'ArrowDown') {
			e.preventDefault();
			selectedIndex = Math.min(selectedIndex + 1, flatItems.length - 1);
			scrollToSelected();
			return;
		}
		if (e.key === 'ArrowUp') {
			e.preventDefault();
			selectedIndex = Math.max(selectedIndex - 1, 0);
			scrollToSelected();
			return;
		}
		if (e.key === 'Enter') {
			e.preventDefault();
			const item = flatItems[selectedIndex];
			if (item) executeItem(item);
		}
	}

	function scrollToSelected() {
		queueMicrotask(() => {
			const el = listRef?.querySelector(`[data-idx="${selectedIndex}"]`);
			if (el && 'scrollIntoView' in el)
				(el as HTMLElement).scrollIntoView({ block: 'nearest' });
		});
	}

	let flatIdxOffset = $derived.by(() => {
		// helper for index assignment in template
		return 0;
	});

	function indexOfItem(predicate: (i: FlatItem) => boolean): number {
		return flatItems.findIndex(predicate);
	}
</script>

<svelte:window onkeydown={onKeydown} />

<Drawer open={paletteStore.open} onclose={close} snaps={[0.65, 0.9]}>
	{#snippet children({ handle, content, footer })}
		<div {@attach handle} class="flex justify-center pb-2 pt-3">
			<div class="h-1 w-10 rounded-full bg-slate-200 dark:bg-white/10"></div>
		</div>

		<!-- Search input — sibling of content so the Drawer sees the scrollable
			list directly via @attach content. Nesting another wrapper between them
			breaks the drag-vs-scroll arbitration: contentRef.scrollTop would read 0
			even when the inner list is scrolled, so scrolling up from the bottom
			would drag the sheet closed instead of the list. -->
		<div class="mb-3 shrink-0 px-4">
			<div class="flex h-11 items-center gap-2 rounded-2xl border border-slate-100 bg-surface px-3 dark:border-white/5 dark:bg-white/5">
				<Search class="text-slate-400 dark:text-slate-500" />
				<input
					bind:this={inputRef}
					bind:value={query}
					placeholder="Suchen oder Befehl eingeben..."
					class="h-full flex-1 bg-transparent text-sm text-slate-900 outline-none placeholder:text-slate-400 dark:text-slate-100 dark:placeholder:text-slate-500"
					autocomplete="off"
					spellcheck="false"
				/>
				<button
					onclick={() => (query = '')}
					class="rounded-lg p-1 text-slate-400 transition-opacity hover:bg-slate-100 dark:hover:bg-white/10 {query
						? 'opacity-100'
						: 'pointer-events-none opacity-0'}"
					aria-label="Eingabe löschen"
					tabindex={query ? 0 : -1}
				>
					<Close />
				</button>
			</div>
		</div>

		<div bind:this={listRef} {@attach content} class="px-4 pb-4">
				{#if bookMatch}
					<div class="mb-2 mt-2 flex items-center gap-2 px-2">
						<span class="inline-flex items-center gap-1.5 rounded-full bg-primary/10 px-2.5 py-1 text-xs font-medium text-primary">
							Quelle: {bookFilter}
							<button
								onclick={() => (query = bookRest)}
								class="-mr-1 rounded-full p-0.5 hover:bg-primary/20"
								aria-label="Filter l&ouml;schen"
							>
								<Close class="text-[12px]" />
							</button>
						</span>
					</div>
				{/if}

				{#if quickAddAvailable}
					{@const idx = indexOfItem((it) => it.kind === 'quickadd')}
					<p class="mb-1 mt-2 px-2 text-[11px] font-bold uppercase tracking-wider text-primary">Hinzuf&uuml;gen</p>
					<button
						data-idx={idx}
						onclick={() => executeItem({ kind: 'quickadd', value: query.trim() })}
						disabled={adding}
						class="flex w-full items-center gap-3 rounded-xl px-3 py-2.5 text-left transition-colors disabled:opacity-50 {selectedIndex === idx ? 'border-l-[3px] border-primary bg-primary/10' : 'hover:bg-slate-50 dark:hover:bg-white/5'}"
					>
						<Add class="text-primary" />
						<span class="text-sm font-medium text-slate-900 dark:text-slate-100">
							Zum Lexikon hinzuf&uuml;gen &laquo;{query.trim()}&raquo;
						</span>
					</button>
				{/if}

				{#if packResults.length > 0}
					<p class="mb-1 mt-3 px-2 text-[11px] font-bold uppercase tracking-wider text-primary">Pakete</p>
					{#each packResults as p (p.id)}
						{@const idx = indexOfItem((it) => it.kind === 'pack' && it.value.id === p.id)}
						<button
							data-idx={idx}
							onclick={() => executeItem({ kind: 'pack', value: p })}
							class="flex w-full items-center gap-3 rounded-xl px-3 py-2.5 text-left transition-colors {selectedIndex === idx ? 'border-l-[3px] border-primary bg-primary/10' : 'hover:bg-slate-50 dark:hover:bg-white/5'}"
						>
							{#if p.kind === 'dictionary'}
								<Dictionary class="text-slate-400" />
							{:else}
								<Inventory2 class="text-slate-400" />
							{/if}
							<div class="flex min-w-0 flex-1 items-center gap-2">
								<span class="truncate text-sm font-medium text-slate-900 dark:text-slate-100">{p.name}</span>
								<span class="shrink-0 rounded px-1.5 py-0.5 text-[9px] font-bold uppercase tracking-wider {tagBadgeClass(p.tag)}">{tagLabel(p.tag)}</span>
							</div>
						</button>
					{/each}
				{/if}

				{#if drillPacks.length > 0}
					<p class="mb-1 mt-3 px-2 text-[11px] font-bold uppercase tracking-wider text-primary">Drill starten</p>
					{#each drillPacks as p (p.id)}
						{@const idx = indexOfItem((it) => it.kind === 'drill-pack' && it.value.id === p.id)}
						<button
							data-idx={idx}
							onclick={() => executeItem({ kind: 'drill-pack', value: p })}
							class="flex w-full items-center gap-3 rounded-xl px-3 py-2.5 text-left transition-colors {selectedIndex === idx ? 'border-l-[3px] border-primary bg-primary/10' : 'hover:bg-slate-50 dark:hover:bg-white/5'}"
						>
							<PlayArrow class="text-primary" />
							<span class="truncate text-sm font-medium text-slate-900 dark:text-slate-100">Drill: {p.name}</span>
						</button>
					{/each}
				{/if}

				{#if lastReviewed}
					{@const idx = indexOfItem((it) => it.kind === 'last-reviewed')}
					<p class="mb-1 mt-2 px-2 text-[11px] font-bold uppercase tracking-wider text-primary">Zuletzt ge&uuml;bt</p>
					<button
						data-idx={idx}
						onclick={() => executeItem({ kind: 'last-reviewed', value: lastReviewed })}
						class="flex w-full items-center gap-3 rounded-xl px-3 py-2.5 text-left transition-colors {selectedIndex === idx ? 'border-l-[3px] border-primary bg-primary/10' : 'hover:bg-slate-50 dark:hover:bg-white/5'}"
					>
						<PlayCircle class="text-primary" />
						<div class="flex min-w-0 flex-1 flex-col">
							<span class="truncate text-sm font-medium text-slate-900 dark:text-slate-100">{lastReviewed.word}</span>
							{#if lastReviewed.translation}
								<span class="truncate text-xs text-slate-500 dark:text-slate-400">{lastReviewed.translation}</span>
							{/if}
						</div>
					</button>
				{/if}

				{#if recentChars.length > 0}
					<p class="mb-1 mt-3 px-2 text-[11px] font-bold uppercase tracking-wider text-primary">K&uuml;rzlich</p>
					<div class="flex flex-wrap gap-1.5 px-2 py-1">
						{#each recentChars as ch (ch)}
							{@const idx = indexOfItem((it) => it.kind === 'recent-char' && it.value === ch)}
							<button
								data-idx={idx}
								onclick={() => executeItem({ kind: 'recent-char', value: ch })}
								class="chinese-char flex size-10 items-center justify-center rounded-lg text-xl transition-colors {selectedIndex === idx ? 'bg-primary text-white' : 'bg-slate-100 text-slate-900 hover:bg-primary/10 dark:bg-white/5 dark:text-slate-100 dark:hover:bg-primary/20'}"
							>
								{ch}
							</button>
						{/each}
					</div>
				{/if}

				{#if showRecent}
					<p class="mb-1 mt-3 px-2 text-[11px] font-bold uppercase tracking-wider text-primary">Letzte Suchen</p>
					{#each recent as r, i (r)}
						{@const idx = indexOfItem((it) => it.kind === 'recent' && it.value === r)}
						<button
							data-idx={idx}
							onclick={() => executeItem({ kind: 'recent', value: r })}
							class="flex w-full items-center gap-3 rounded-xl px-3 py-2.5 text-left transition-colors {selectedIndex === idx ? 'border-l-[3px] border-primary bg-primary/10' : 'hover:bg-slate-50 dark:hover:bg-white/5'}"
						>
							<Today class="text-slate-400" />
							<span class="text-sm text-slate-700 dark:text-slate-200">{r}</span>
						</button>
					{/each}
				{/if}

				{#each Object.entries(groupedActions) as [group, items] (group)}
					<p class="mb-1 mt-3 px-2 text-[11px] font-bold uppercase tracking-wider text-primary">{group}</p>
					{#each items as a (a.id)}
						{@const idx = indexOfItem((it) => it.kind === 'action' && it.value.id === a.id)}
						<button
							data-idx={idx}
							onclick={() => executeItem({ kind: 'action', value: a })}
							class="flex w-full items-center gap-3 rounded-xl px-3 py-2.5 text-left transition-colors {selectedIndex === idx ? 'border-l-[3px] border-primary bg-primary/10' : 'hover:bg-slate-50 dark:hover:bg-white/5'} {a.danger ? 'text-red-600 dark:text-red-400' : 'text-slate-800 dark:text-slate-100'}"
						>
							<span class="material-symbols-outlined text-base text-slate-400">{a.icon}</span>
							<span class="text-sm font-medium">{a.label}</span>
						</button>
					{/each}
				{/each}

				{#if cardResults.length > 0}
					<p class="mb-1 mt-3 px-2 text-[11px] font-bold uppercase tracking-wider text-primary">Karten</p>
					{#each cardResults as c (c.id)}
						{@const idx = indexOfItem((it) => it.kind === 'card' && it.value.id === c.id)}
						<button
							data-idx={idx}
							onclick={() => executeItem({ kind: 'card', value: c })}
							class="flex w-full flex-col gap-0.5 rounded-xl px-3 py-2.5 text-left transition-colors {selectedIndex === idx ? 'border-l-[3px] border-primary bg-primary/10' : 'hover:bg-slate-50 dark:hover:bg-white/5'}"
						>
							<div class="flex items-baseline gap-2">
								<span class="text-base font-medium text-slate-900 dark:text-slate-100">{c.word}</span>
								{#if c.pinyin}
									<span class="text-xs text-slate-500 dark:text-slate-400">{c.pinyin}</span>
								{/if}
							</div>
							{#if c.translation}
								<span class="truncate text-xs text-slate-500 dark:text-slate-400">{c.translation}</span>
							{/if}
							{#if c.context && (bookMatch || c.context.toLowerCase().includes(searchQuery.toLowerCase()))}
								<span class="truncate text-[11px] italic text-slate-400 dark:text-slate-500">&bdquo;{c.context.slice(0, 80)}{c.context.length > 80 ? '…' : ''}&ldquo;</span>
							{/if}
						</button>
					{/each}
				{/if}

				{#if pinyinResults.length > 0}
					<p class="mb-1 mt-3 px-2 text-[11px] font-bold uppercase tracking-wider text-primary">Pinyin</p>
					{#each pinyinResults as p (p.id)}
						{@const idx = indexOfItem((it) => it.kind === 'pinyin' && it.value.id === p.id)}
						<button
							data-idx={idx}
							onclick={() => executeItem({ kind: 'pinyin', value: p })}
							class="flex w-full items-baseline gap-2 rounded-xl px-3 py-2.5 text-left transition-colors {selectedIndex === idx ? 'border-l-[3px] border-primary bg-primary/10' : 'hover:bg-slate-50 dark:hover:bg-white/5'}"
						>
							<span class="text-base font-medium text-slate-900 dark:text-slate-100">{p.word}</span>
							<span class="text-xs text-slate-500 dark:text-slate-400">{p.pinyin}</span>
							{#if p.translation}
								<span class="ml-auto truncate text-xs text-slate-400 dark:text-slate-500">{p.translation}</span>
							{/if}
						</button>
					{/each}
				{/if}

				{#if dictResults.length > 0 || wiktResults.length > 0}
					<p class="mb-1 mt-3 px-2 text-[11px] font-bold uppercase tracking-wider text-primary">W&ouml;rterbuch</p>
					{#each dictResults as d, i (d.simplified + i)}
						{@const idx = indexOfItem((it) => it.kind === 'dict' && it.value === d)}
						<button
							data-idx={idx}
							onclick={() => executeItem({ kind: 'dict', value: d })}
							class="flex w-full flex-col gap-0.5 rounded-xl px-3 py-2.5 text-left transition-colors {selectedIndex === idx ? 'border-l-[3px] border-primary bg-primary/10' : 'hover:bg-slate-50 dark:hover:bg-white/5'}"
						>
							<div class="flex items-baseline gap-2">
								<span class="text-base font-medium text-slate-900 dark:text-slate-100">{d.simplified}</span>
								<span class="text-xs text-slate-500 dark:text-slate-400">{d.pinyin}</span>
							</div>
							<span class="truncate text-xs text-slate-500 dark:text-slate-400">{d.english}</span>
						</button>
					{/each}
					{#each wiktResults as w, i (w.word + i)}
						{@const idx = indexOfItem((it) => it.kind === 'wikt' && it.value === w)}
						<button
							data-idx={idx}
							onclick={() => executeItem({ kind: 'wikt', value: w })}
							class="flex w-full flex-col gap-0.5 rounded-xl px-3 py-2.5 text-left transition-colors {selectedIndex === idx ? 'border-l-[3px] border-primary bg-primary/10' : 'hover:bg-slate-50 dark:hover:bg-white/5'}"
						>
							<div class="flex items-baseline gap-2">
								<span class="text-base font-medium text-slate-900 dark:text-slate-100">{w.word}</span>
								{#if w.pos}
									<span class="rounded bg-primary/10 px-1.5 py-0.5 text-[10px] font-bold text-primary">{w.pos}</span>
								{/if}
							</div>
							<span class="truncate text-xs text-slate-500 dark:text-slate-400">{w.definition}</span>
						</button>
					{/each}
				{/if}

				{#if singleHanziHit}
					<p class="mb-1 mt-3 px-2 text-[11px] font-bold uppercase tracking-wider text-primary">Zeichen</p>
					{@const idx = indexOfItem((it) => it.kind === 'character')}
					<button
						data-idx={idx}
						onclick={() => executeItem({ kind: 'character', value: query.trim() })}
						class="flex w-full items-center gap-3 rounded-xl px-3 py-2.5 text-left transition-colors {selectedIndex === idx ? 'border-l-[3px] border-primary bg-primary/10' : 'hover:bg-slate-50 dark:hover:bg-white/5'}"
					>
						<span class="text-2xl font-light text-slate-900 dark:text-slate-100">{query.trim()}</span>
						<span class="text-sm text-slate-500 dark:text-slate-400">Zeichen-Detail &ouml;ffnen</span>
					</button>
				{/if}

			{#if flatItems.length === 0 && query.trim()}
				<div class="px-3 py-8 text-center text-sm text-slate-400 dark:text-slate-500">Keine Ergebnisse</div>
			{/if}
		</div>

		<div {@attach footer} class="flex items-center justify-center gap-4 border-t border-slate-100 px-4 py-3 text-[11px] text-slate-400 dark:border-white/5 dark:text-slate-500">
			<span><kbd class="rounded bg-slate-100 px-1.5 py-0.5 font-mono dark:bg-white/10">&uarr;&darr;</kbd> Navigation</span>
			<span><kbd class="rounded bg-slate-100 px-1.5 py-0.5 font-mono dark:bg-white/10">&crarr;</kbd> Ausw&auml;hlen</span>
			<span><kbd class="rounded bg-slate-100 px-1.5 py-0.5 font-mono dark:bg-white/10">Esc</kbd> Schlie&szlig;en</span>
		</div>
	{/snippet}
</Drawer>
