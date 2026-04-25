<script lang="ts">
	import AddCircle from '$lib/icons/AddCircle.svelte';
	import CheckCircle from '$lib/icons/CheckCircle.svelte';
	import Close from '$lib/icons/Close.svelte';
	import HourglassEmpty from '$lib/icons/HourglassEmpty.svelte';
	import Dictionary from '$lib/icons/Dictionary.svelte';
	import Search from '$lib/icons/Search.svelte';
	import SearchOff from '$lib/icons/SearchOff.svelte';
	import VolumeUp from '$lib/icons/VolumeUp.svelte';
	import { lookupCedict, lookupWord, addWord, removeWord, type CedictResult, type DictResult } from '$lib/wasm';
	import { speak } from '$lib/speak';
	import { data } from '$lib/data.svelte';
	import { toastStore } from '$lib/toast.svelte';
	import { afterNavigate } from '$app/navigation';
	import { page } from '$app/state';

	type UnifiedResult = {
		type: 'cedict';
		word: string;
		pinyin: string;
		definition: string;
		entry: CedictResult;
	} | {
		type: 'wikt';
		word: string;
		pos: string;
		definition: string;
		entry: DictResult;
	};

	let query = $state('');
	let results: UnifiedResult[] = $state([]);
	let busyWord = $state<string | null>(null);
	let errorMsg = $state('');

	// Map of word → lexicon entry id (for remove support)
	let lexiconMap = $derived(
		new Map(data.lexicon().map((e) => [e.word, e.id]))
	);

	let debounceTimer: ReturnType<typeof setTimeout> | undefined;

	// Fires on initial mount AND on same-route navigations — important
	// because ⌘K does `goto('/dictionary?q=…')`, and SvelteKit reuses the
	// page component when the route matches. With a plain onMount the
	// input + results would freeze on the previous query while the URL
	// silently updated.
	afterNavigate(() => {
		const q = page.url.searchParams.get('q');
		if (q !== null && q !== query) {
			query = q;
			handleInput();
		}
	});

	function hasChinese(text: string): boolean {
		return [...text].some((ch) => {
			const code = ch.codePointAt(0) ?? 0;
			return (code >= 0x4E00 && code <= 0x9FFF) || (code >= 0x3400 && code <= 0x4DBF);
		});
	}

	function handleInput() {
		clearTimeout(debounceTimer);
		const q = query.trim();
		if (!q) {
			results = [];
			return;
		}
		debounceTimer = setTimeout(() => {
			const unified: UnifiedResult[] = [];

			// Search Chinese dictionary if query has CJK chars
			if (hasChinese(q)) {
				for (const r of lookupCedict(q)) {
					unified.push({ type: 'cedict', word: r.simplified, pinyin: r.pinyin, definition: r.english, entry: r });
				}
			}

			// Search EN/DE dictionaries
			for (const r of lookupWord(q)) {
				unified.push({ type: 'wikt', word: r.word, pos: r.pos, definition: r.definition, entry: r });
			}

			// If no Chinese match, try CEDICT anyway (pinyin/english search)
			if (!hasChinese(q) && unified.length === 0) {
				for (const r of lookupCedict(q)) {
					unified.push({ type: 'cedict', word: r.simplified, pinyin: r.pinyin, definition: r.english, entry: r });
				}
			}

			results = unified;
		}, 150);
	}

	function handleKeydown(e: KeyboardEvent) {
		if (e.key === 'Escape') {
			query = '';
			results = [];
		}
	}

	async function handleToggle(word: string) {
		if (busyWord) return;
		busyWord = word;
		errorMsg = '';
		try {
			const existingId = lexiconMap.get(word);
			if (existingId) {
				await removeWord(existingId);
				toastStore.show(`„${word}" entfernt`);
			} else {
				await addWord(word);
				toastStore.show(`„${word}" zum Lexikon hinzugefügt`);
			}
		} catch (e) {
			const msg = e instanceof Error ? e.message : 'Fehler';
			if (msg.includes('already exists')) {
				toastStore.show(`„${word}" ist bereits im Lexikon`);
			} else {
				toastStore.show(msg);
			}
			data.bump();
		} finally {
			busyWord = null;
		}
	}

	// Recent words from lexicon for empty state
	let recentWords = $derived(
		data.lexicon().slice(0, 12)
	);

	// Default popular words
	const defaultWords = ['你好', '谢谢', '学习', 'hello', 'beautiful', 'Freundschaft', 'Schwebebahn', 'ubiquitous', '中国', '快乐', 'Wanderlust', 'serendipity'];

	function searchWord(word: string) {
		query = word;
		handleInput();
	}

	function splitChars(text: string): string[] {
		return [...text].filter((ch) => ch.charCodeAt(0) > 0x2e80);
	}
</script>

<!-- Search Bar -->
<section class="mt-4">
	<div
		class="flex h-12 items-center overflow-hidden rounded-xl border border-primary/10 bg-primary/5 px-4 transition-all focus-within:border-primary/30"
	>
		<Search class="mr-3 text-[20px] text-primary/40" />
		<input
			type="text"
			bind:value={query}
			oninput={handleInput}
			onkeydown={handleKeydown}
			class="min-w-0 flex-1 border-none bg-transparent p-0 text-base font-normal placeholder:text-primary/40 focus:ring-0"
			placeholder="Wort suchen..."
		/>
		{#if query}
			<button
				onclick={() => {
					query = '';
					results = [];
				}}
				class="p-1 text-primary/40 hover:text-primary"
			>
				<Close class="text-[20px]" />
			</button>
		{/if}
	</div>

	{#if errorMsg}
		<div
			class="mt-2 rounded-xl border border-red-200 bg-red-50 px-4 py-2.5 text-sm text-red-700 dark:border-red-800 dark:bg-red-950 dark:text-red-300"
		>
			{errorMsg}
		</div>
	{/if}
</section>

<!-- Results -->
<section class="mt-6 space-y-3">
	{#if query.trim() && results.length === 0}
		<div
			class="rounded-2xl border border-slate-100 bg-white p-8 text-center shadow-sm dark:border-white/5 dark:bg-white/5"
		>
			<SearchOff class="mb-2 text-[32px] text-slate-300 dark:text-slate-500" />
			<p class="text-sm text-slate-500 dark:text-slate-400">
				Keine Ergebnisse f&uuml;r &laquo;{query.trim()}&raquo;
			</p>
		</div>
	{:else if results.length > 0}
		<h3 class="px-1 text-[11px] font-bold uppercase tracking-wider text-primary">
			{results.length} Ergebnis{results.length !== 1 ? 'se' : ''}
		</h3>

		{#each results as result, i (result.word + i)}
			<div
				class="rounded-2xl border border-slate-100 bg-white p-4 shadow-sm dark:border-white/5 dark:bg-slate-800/40"
			>
				<div class="flex items-start gap-3">
					<div class="min-w-0 flex-1">
						<div class="mb-1 flex flex-wrap items-baseline gap-2">
							{#if result.type === 'cedict'}
								<span class="text-2xl font-light">
									{#each splitChars(result.word) as char}
										<a
											href="/character/{encodeURIComponent(char)}"
											class="chinese-char hover:text-primary">{char}</a
										>
									{/each}
									{#if splitChars(result.word).length === 0}
										<span>{result.word}</span>
									{/if}
								</span>
								<span class="text-sm text-primary/70">{result.pinyin}</span>
							{:else}
								<span class="text-xl font-semibold text-slate-900 dark:text-slate-100">{result.word}</span>
								{#if result.pos}
									<span class="rounded bg-primary/10 px-1.5 py-0.5 text-[10px] font-bold text-primary">{result.pos}</span>
								{/if}
							{/if}
						</div>
						<p class="text-[13px] leading-relaxed text-slate-600 dark:text-slate-400">
							{result.definition}
						</p>
					</div>

					<!-- Actions -->
					<div class="flex shrink-0 items-center gap-1">
						<button
							onclick={() => speak(result.word, result.type === 'cedict' ? 'zh' : 'en')}
							class="rounded-lg p-1.5 text-slate-300 transition-colors hover:bg-slate-100 hover:text-primary dark:text-slate-500 dark:hover:bg-white/10"
							title="Aussprechen"
						>
							<VolumeUp class="text-[20px]" />
						</button>
						<button
							onclick={() => handleToggle(result.word)}
							disabled={busyWord === result.word}
							class="rounded-lg p-1.5 transition-colors disabled:opacity-50 {lexiconMap.has(result.word)
								? 'text-primary hover:bg-red-50 hover:text-red-500 dark:hover:bg-red-950'
								: 'text-slate-300 hover:bg-primary/10 hover:text-primary dark:text-slate-500 dark:hover:bg-primary/20'}"
							title={lexiconMap.has(result.word) ? 'Aus Lexikon entfernen' : 'Zum Lexikon hinzuf\u00fcgen'}
						>
							{#if busyWord === result.word}
								<HourglassEmpty class="text-[20px]" />
							{:else if lexiconMap.has(result.word)}
								<CheckCircle class="text-[20px]" />
							{:else}
								<AddCircle class="text-[20px]" />
							{/if}
						</button>
					</div>
				</div>
			</div>
		{/each}
	{:else}
		<!-- Empty state — no search yet -->
		{#if recentWords.length > 0}
			<h3 class="px-1 text-[11px] font-bold uppercase tracking-wider text-primary">Deine W&ouml;rter</h3>
			<div class="flex flex-wrap gap-2">
				{#each recentWords as entry (entry.id)}
					<button
						onclick={() => searchWord(entry.word)}
						class="flex items-baseline gap-1.5 rounded-full border border-slate-100 dark:border-white/5 bg-white dark:bg-white/5 px-4 py-2 shadow-sm transition-colors hover:bg-primary/5"
					>
						<span class="text-lg font-medium text-slate-900 dark:text-slate-100" class:chinese-char={entry.language === 'zh'}>{entry.word}</span>
						{#if entry.pinyin}
							<span class="text-xs text-slate-400 dark:text-slate-500">{entry.pinyin}</span>
						{/if}
					</button>
				{/each}
			</div>
		{/if}

		<h3 class="px-1 text-[11px] font-bold uppercase tracking-wider text-slate-400 dark:text-slate-500">Vorschl&auml;ge</h3>
		<div class="flex flex-wrap gap-2">
			{#each defaultWords as word (word)}
				<button
					onclick={() => searchWord(word)}
					class="rounded-full border border-slate-100 dark:border-white/5 bg-white dark:bg-white/5 px-4 py-2 text-base shadow-sm transition-colors hover:bg-primary/5 text-slate-900 dark:text-slate-100"
				>
					{word}
				</button>
			{/each}
		</div>

		<div
			class="rounded-2xl border border-slate-100 bg-white p-8 text-center shadow-sm dark:border-white/5 dark:bg-white/5"
		>
			<Dictionary class="mb-2 text-[32px] text-primary/30" />
			<p class="text-sm text-slate-500 dark:text-slate-400">
				Durchsuche CC-CEDICT mit 124.000 Eintr&auml;gen.
			</p>
			<p class="mt-1 text-xs text-slate-400 dark:text-slate-500">
				Suche nach Schriftzeichen, Pinyin oder Englisch.
			</p>
		</div>
	{/if}
</section>
