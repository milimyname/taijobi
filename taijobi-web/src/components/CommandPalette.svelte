<script lang="ts">
	import { goto } from '$app/navigation';
	import Drawer from './Drawer.svelte';
	import Search from '$lib/icons/Search.svelte';
	import Close from '$lib/icons/Close.svelte';
	import Today from '$lib/icons/Today.svelte';
	import { paletteStore } from '$lib/commandPalette.svelte';
	import { searchCards, lookupCedict, type CardSearchResult, type CedictResult } from '$lib/wasm';
	import { searchIndex, type PinyinHit } from '$lib/searchIndex.svelte';
	import { getActions, type PaletteAction } from '$lib/actions.svelte';
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
	let recent = $state<string[]>(loadRecent());
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

	const filteredActions = $derived.by(() => {
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

	const groupedActions = $derived.by(() => {
		const groups: Record<string, PaletteAction[]> = {};
		for (const a of filteredActions) {
			(groups[a.group] ??= []).push(a);
		}
		return groups;
	});

	const showRecent = $derived(query.trim() === '' && recent.length > 0);
	const singleHanziHit = $derived(isSingleHanzi(query.trim()));

	// Debounced async searches
	$effect(() => {
		const q = query.trim();
		if (debounceHandle) clearTimeout(debounceHandle);
		if (!q) {
			cardResults = [];
			pinyinResults = [];
			dictResults = [];
			return;
		}
		debounceHandle = setTimeout(() => {
			cardResults = searchCards(q, 8);
			searchIndex
				.fuzzyPinyin(q, 8)
				.then((hits) => {
					const seen = new Set(cardResults.map((c) => c.id));
					pinyinResults = hits.filter((h) => !seen.has(h.id));
				})
				.catch(() => (pinyinResults = []));
			if (data.chineseDataLoaded()) {
				dictResults = lookupCedict(q).slice(0, 5);
			} else {
				dictResults = [];
			}
		}, 200);
	});

	// Flat item list for keyboard nav
	type FlatItem =
		| { kind: 'recent'; value: string }
		| { kind: 'action'; value: PaletteAction }
		| { kind: 'card'; value: CardSearchResult }
		| { kind: 'pinyin'; value: PinyinHit }
		| { kind: 'dict'; value: CedictResult }
		| { kind: 'character'; value: string };

	const flatItems = $derived.by(() => {
		const items: FlatItem[] = [];
		if (showRecent) {
			for (const r of recent) items.push({ kind: 'recent', value: r });
		}
		for (const group of Object.values(groupedActions)) {
			for (const a of group) items.push({ kind: 'action', value: a });
		}
		for (const c of cardResults) items.push({ kind: 'card', value: c });
		for (const p of pinyinResults) items.push({ kind: 'pinyin', value: p });
		for (const d of dictResults) items.push({ kind: 'dict', value: d });
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
				goto(`/lessons/${encodeURIComponent(c.pack_id)}`);
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
				{#if showRecent}
					<p class="mb-1 mt-2 px-2 text-[11px] font-bold uppercase tracking-wider text-primary">Letzte Suchen</p>
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

				{#if dictResults.length > 0}
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
