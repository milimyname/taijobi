<script lang="ts">
	import Search from '$lib/icons/Search.svelte';
	import Translate from '$lib/icons/Translate.svelte';
	import { getLexicon, getPacks, getLessons, getVocabulary, type VocabEntry, type LexiconEntry } from '$lib/wasm';

	let filter = $state<'all' | 'lexicon' | string>('all');
	let search = $state('');

	interface CharInfo {
		char: string;
		pinyin: string | null;
		translation: string | null;
		source: string;
	}

	// Collect all unique Chinese characters from lexicon + packs
	function collectCharacters(): CharInfo[] {
		const seen = new Map<string, CharInfo>();

		// From lexicon
		const lexicon = getLexicon();
		for (const entry of lexicon) {
			if (entry.language !== 'zh') continue;
			addChars(seen, entry.word, entry.pinyin, entry.translation, 'lexicon');
		}

		// From installed packs
		const packs = getPacks();
		for (const pack of packs) {
			const lessons = getLessons(pack.id);
			for (const lesson of lessons) {
				const vocab = getVocabulary(lesson.id);
				for (const word of vocab) {
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
		source: string,
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

	let allChars = $state<CharInfo[]>([]);

	$effect(() => {
		allChars = collectCharacters();
	});

	let filtered = $derived.by(() => {
		let chars = allChars;
		if (filter === 'lexicon') {
			chars = chars.filter((c) => c.source === 'lexicon');
		} else if (filter !== 'all') {
			chars = chars.filter((c) => c.source === filter);
		}
		if (search.trim()) {
			const q = search.trim().toLowerCase();
			chars = chars.filter(
				(c) =>
					c.char.includes(q) ||
					(c.pinyin && c.pinyin.toLowerCase().includes(q)) ||
					(c.translation && c.translation.toLowerCase().includes(q)),
			);
		}
		return chars;
	});

	let packs = $derived(getPacks());
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
<section class="mt-3 flex gap-2 overflow-x-auto no-scrollbar">
	<button
		onclick={() => (filter = 'all')}
		class="flex h-9 shrink-0 items-center rounded-full px-5 text-sm font-semibold transition-colors {filter === 'all'
			? 'bg-primary text-white'
			: 'bg-slate-100 dark:bg-white/10 text-slate-600 dark:text-slate-300'}"
	>
		Alle ({allChars.length})
	</button>
	<button
		onclick={() => (filter = 'lexicon')}
		class="flex h-9 shrink-0 items-center rounded-full px-5 text-sm font-medium transition-colors {filter === 'lexicon'
			? 'bg-primary text-white'
			: 'bg-slate-100 dark:bg-white/10 text-slate-600 dark:text-slate-300'}"
	>
		Lexikon
	</button>
	{#each packs as pack (pack.id)}
		<button
			onclick={() => (filter = pack.id)}
			class="flex h-9 shrink-0 items-center rounded-full px-5 text-sm font-medium transition-colors {filter === pack.id
				? 'bg-primary text-white'
				: 'bg-slate-100 dark:bg-white/10 text-slate-600 dark:text-slate-300'}"
		>
			{pack.name}
		</button>
	{/each}
</section>

<!-- Character Grid -->
<section class="mt-6">
	<h3 class="mb-3 text-[11px] font-bold uppercase tracking-wider text-primary">
		{filtered.length} Zeichen
	</h3>
	{#if filtered.length === 0}
		<div class="rounded-2xl border border-slate-100 dark:border-white/5 bg-white dark:bg-white/5 p-8 text-center shadow-sm">
			<Translate class="mb-2 text-[32px] text-slate-300 dark:text-slate-500 dark:text-slate-400" />
			<p class="text-sm text-slate-500 dark:text-slate-400">Keine Zeichen gefunden.</p>
		</div>
	{:else}
		<div class="grid grid-cols-5 gap-2 sm:grid-cols-7">
			{#each filtered as info (info.char)}
				<a
					href="/character/{encodeURIComponent(info.char)}"
					class="flex flex-col items-center rounded-xl border border-slate-100 dark:border-white/5 bg-white dark:bg-white/5 p-3 shadow-sm transition-colors hover:border-primary/20 hover:bg-primary/5"
				>
					<span class="chinese-char text-3xl text-slate-900 dark:text-slate-100">{info.char}</span>
				</a>
			{/each}
		</div>
	{/if}
</section>

<div class="h-8"></div>
