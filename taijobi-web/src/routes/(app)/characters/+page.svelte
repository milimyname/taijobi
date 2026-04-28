<script lang="ts">
	import Search from '$lib/icons/Search.svelte';
	import Translate from '$lib/icons/Translate.svelte';
	import {
		getLexicon,
		getPacks,
		getLessons,
		getVocabulary,
		listDecompChars
	} from '$lib/wasm';
	import { data } from '$lib/data.svelte';

	type FilterKey = 'all' | 'lexicon' | 'decomp' | string;

	let filter = $state<FilterKey>('all');
	let search = $state('');

	interface CharInfo {
		char: string;
		pinyin: string | null;
		translation: string | null;
		source: string;
	}

	// Lexicon + pack characters — the user's content.
	function collectUserChars(): CharInfo[] {
		const seen = new Map<string, CharInfo>();

		for (const entry of getLexicon()) {
			if (entry.language !== 'zh') continue;
			addChars(seen, entry.word, entry.pinyin, entry.translation, 'lexicon');
		}

		for (const pack of getPacks()) {
			for (const lesson of getLessons(pack.id)) {
				for (const word of getVocabulary(lesson.id)) {
					addChars(seen, word.word, word.pinyin, word.translation, pack.id);
				}
			}
		}

		return [...seen.values()];
	}

	function addChars(
		seen: Map<string, CharInfo>,
		word: string,
		pinyin: string | null,
		translation: string | null,
		source: string
	) {
		for (const ch of word) {
			const code = ch.codePointAt(0) ?? 0;
			if (code >= 0x4e00 && code <= 0x9fff) {
				if (!seen.has(ch)) {
					seen.set(ch, { char: ch, pinyin, translation, source });
				}
			}
		}
	}

	let userChars = $state<CharInfo[]>([]);
	let decompChars = $state<CharInfo[]>([]);

	// Rebuild user chars on every data change (bump-driven reactivity).
	$effect(() => {
		data.version();
		userChars = collectUserChars();
	});

	let chineseDataLoaded = $derived(data.chineseDataLoaded());

	// Lazy-load the ~9500-char decomp set only when the user picks that filter
	// (or searches for something while the decomp set is a plausible match).
	// The JSON parse for 9500 entries runs on the main thread; keep it off the
	// dashboard by default.
	$effect(() => {
		if (filter !== 'decomp') return;
		if (!chineseDataLoaded) return;
		if (decompChars.length > 0) return;
		const raw = listDecompChars();
		decompChars = raw.map((e) => ({
			char: e.c,
			pinyin: e.p || null,
			translation: null,
			source: 'decomp'
		}));
	});

	const allChars = $derived(filter === 'decomp' ? decompChars : userChars);

	const filtered = $derived.by(() => {
		let chars = allChars;
		if (filter === 'lexicon') {
			chars = chars.filter((c) => c.source === 'lexicon');
		} else if (filter !== 'all' && filter !== 'decomp') {
			chars = chars.filter((c) => c.source === filter);
		}
		if (search.trim()) {
			const q = search.trim().toLowerCase();
			chars = chars.filter(
				(c) =>
					c.char.includes(q) ||
					(c.pinyin && c.pinyin.toLowerCase().includes(q)) ||
					(c.translation && c.translation.toLowerCase().includes(q))
			);
		}
		return chars;
	});

	const PAGE_SIZE = 200;
	let displayed = $state<CharInfo[]>([]);
	let hasMore = $state(true);
	let loadingMore = $state(false);

	function loadMore(): void {
		if (loadingMore || !hasMore) return;
		loadingMore = true;
		const next = filtered.slice(displayed.length, displayed.length + PAGE_SIZE);
		if (next.length === 0) {
			hasMore = false;
		} else {
			displayed = [...displayed, ...next];
			if (displayed.length >= filtered.length) hasMore = false;
		}
		loadingMore = false;
	}

	// Reset displayed when filter/search changes
	$effect(() => {
		const chars = filtered;
		displayed = chars.slice(0, PAGE_SIZE);
		hasMore = chars.length > PAGE_SIZE;
	});

	// IntersectionObserver sentinel — loads more as user scrolls
	$effect(() => {
		const sentinel = document.getElementById('chars-sentinel');
		if (!sentinel) return;
		const io = new IntersectionObserver(
			(entries) => {
				if (entries.some((e) => e.isIntersecting)) loadMore();
			},
			{ rootMargin: '400px' }
		);
		io.observe(sentinel);
		return () => io.disconnect();
	});

	const packs = $derived(data.packs());
</script>

<!-- Search -->
<section class="mt-4">
	<div
		class="flex h-12 items-center overflow-hidden rounded-xl border border-primary/10 bg-primary/5 px-4 transition-all focus-within:border-primary/30"
	>
		<Search class="mr-2 text-primary/40" />
		<input
			type="text"
			bind:value={search}
			class="min-w-0 flex-1 border-none bg-transparent p-0 text-base placeholder:text-primary/40 focus:ring-0"
			placeholder="Zeichen, Pinyin oder Bedeutung..."
		/>
	</div>
</section>

<!-- Filter Chips -->
<div class="no-scrollbar mt-3 flex gap-2 overflow-x-auto px-2 py-1 [-webkit-overflow-scrolling:touch]">
	<button
		onclick={() => (filter = 'all')}
		class="flex h-9 shrink-0 items-center rounded-full px-5 text-sm font-semibold transition-colors {filter ===
		'all'
			? 'bg-primary text-white'
			: 'bg-slate-100 text-slate-600 dark:bg-white/10 dark:text-slate-300'}"
	>
		Alle ({userChars.length})
	</button>
	<button
		onclick={() => (filter = 'lexicon')}
		class="flex h-9 shrink-0 items-center rounded-full px-5 text-sm font-medium transition-colors {filter ===
		'lexicon'
			? 'bg-primary text-white'
			: 'bg-slate-100 text-slate-600 dark:bg-white/10 dark:text-slate-300'}"
	>
		Lexikon
	</button>
	{#each packs as pack (pack.id)}
		<button
			onclick={() => (filter = pack.id)}
			class="flex h-9 shrink-0 items-center rounded-full px-5 text-sm font-medium transition-colors {filter ===
			pack.id
				? 'bg-primary text-white'
				: 'bg-slate-100 text-slate-600 dark:bg-white/10 dark:text-slate-300'}"
		>
			{pack.name}
		</button>
	{/each}
	{#if chineseDataLoaded}
		<button
			onclick={() => (filter = 'decomp')}
			class="flex h-9 shrink-0 items-center rounded-full px-5 text-sm font-medium transition-colors {filter ===
			'decomp'
				? 'bg-primary text-white'
				: 'bg-slate-100 text-slate-600 dark:bg-white/10 dark:text-slate-300'}"
		>
			Alle Zeichen
		</button>
	{/if}
	<!-- Spacer to show end of scroll -->
	<div class="w-2 shrink-0"></div>
</div>

<!-- Character Grid -->
<section class="mt-6">
	<h3 class="mb-3 text-[11px] font-bold uppercase tracking-wider text-primary">
		{filtered.length} Zeichen
	</h3>
	{#if displayed.length === 0}
		<div
			class="rounded-2xl border border-slate-100 bg-white p-8 text-center shadow-sm dark:border-white/5 dark:bg-white/5"
		>
			<Translate class="mx-auto mb-2 block text-[32px] text-slate-300 dark:text-slate-500" />
			{#if filter === 'decomp'}
				<p class="text-sm text-slate-500 dark:text-slate-400">Lädt Zeichen-Datenbank…</p>
			{:else if allChars.length === 0 && chineseDataLoaded}
				<p class="text-sm font-medium text-slate-700 dark:text-slate-200">Du hast noch keine eigenen Zeichen.</p>
				<p class="mt-2 text-sm text-slate-500 dark:text-slate-400">
					Diese Ansicht zeigt nur Zeichen aus deinem <b>Lexikon</b> und installierten <b>Lehrbuch-Paketen</b>.
					Das chinesische Wörterbuch ist installiert — wechsle zu <b>Alle Zeichen</b> für die volle 9.500-Zeichen-Datenbank.
				</p>
				<div class="mt-4 flex flex-col items-center gap-2 sm:flex-row sm:justify-center">
					<button
						onclick={() => (filter = 'decomp')}
						class="inline-flex items-center justify-center rounded-xl bg-primary px-4 py-2.5 text-sm font-bold text-white shadow-sm transition-colors hover:bg-primary/90"
					>
						Alle Zeichen anzeigen
					</button>
					<a
						href="/packs"
						class="inline-flex items-center justify-center rounded-xl border border-slate-200 px-4 py-2.5 text-sm font-medium text-slate-700 transition-colors hover:bg-slate-50 dark:border-white/10 dark:text-slate-200 dark:hover:bg-white/10"
					>
						HSK-Paket installieren
					</a>
				</div>
			{:else if allChars.length === 0}
				<p class="text-sm font-medium text-slate-700 dark:text-slate-200">Noch keine Zeichen.</p>
				<p class="mt-2 text-sm text-slate-500 dark:text-slate-400">
					Diese Seite zeigt Zeichen aus <b>Lehrbuch-Paketen</b> und deinem <b>Lexikon</b>. Für die
					komplette Zeichen-Datenbank (9.500) installiere das chinesische Wörterbuch.
				</p>
				<div class="mt-4 flex flex-col items-center gap-2 sm:flex-row sm:justify-center">
					<a
						href="/packs?kind=dictionary"
						class="inline-flex items-center justify-center rounded-xl bg-primary px-4 py-2.5 text-sm font-bold text-white shadow-sm transition-colors hover:bg-primary/90"
					>
						Wörterbuch installieren
					</a>
					<a
						href="/packs"
						class="inline-flex items-center justify-center rounded-xl border border-slate-200 px-4 py-2.5 text-sm font-medium text-slate-700 transition-colors hover:bg-slate-50 dark:border-white/10 dark:text-slate-200 dark:hover:bg-white/10"
					>
						HSK-Paket installieren
					</a>
				</div>
			{:else}
				<p class="text-sm text-slate-500 dark:text-slate-400">Keine Treffer für diesen Filter.</p>
			{/if}
		</div>
	{:else}
		<div class="grid grid-cols-5 gap-2 sm:grid-cols-7">
			{#each displayed as info (info.char)}
				<a
					href="/character/{encodeURIComponent(info.char)}"
					style="content-visibility: auto; contain-intrinsic-size: 4rem 4rem;"
					class="flex flex-col items-center rounded-xl border border-slate-100 bg-white p-3 shadow-sm transition-colors hover:border-primary/20 hover:bg-primary/5 dark:border-white/5 dark:bg-white/5"
				>
					<span class="chinese-char text-3xl text-slate-900 dark:text-slate-100">{info.char}</span>
					{#if info.pinyin}
						<span class="mt-1 text-[10px] text-primary/70 dark:text-accent">{info.pinyin}</span>
					{/if}
				</a>
			{/each}
		</div>
		<!-- Sentinel for infinite scroll -->
		<div id="chars-sentinel" class="h-4 w-full"></div>
	{/if}
</section>

<div class="h-8"></div>
