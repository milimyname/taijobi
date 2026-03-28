<script lang="ts">
	import { lookupCedict, addWord, removeWord, type CedictResult } from '$lib/wasm';
	import { speak } from '$lib/speak';
	import { data } from '$lib/data.svelte';

	let query = $state('');
	let results: CedictResult[] = $state([]);
	let busyWord = $state<string | null>(null);
	let errorMsg = $state('');

	// Map of word → lexicon entry id (for remove support)
	let lexiconMap = $derived(
		new Map(data.lexicon().filter((e) => e.language === 'zh').map((e) => [e.word, e.id]))
	);

	let debounceTimer: ReturnType<typeof setTimeout> | undefined;

	function handleInput() {
		clearTimeout(debounceTimer);
		const q = query.trim();
		if (!q) {
			results = [];
			return;
		}
		debounceTimer = setTimeout(() => {
			results = lookupCedict(q);
		}, 150);
	}

	function handleKeydown(e: KeyboardEvent) {
		if (e.key === 'Escape') {
			query = '';
			results = [];
		}
	}

	async function handleToggle(entry: CedictResult) {
		if (busyWord) return;
		busyWord = entry.simplified;
		errorMsg = '';
		try {
			const existingId = lexiconMap.get(entry.simplified);
			if (existingId) {
				await removeWord(existingId);
			} else {
				await addWord(entry.simplified);
			}
		} catch (e) {
			errorMsg = e instanceof Error ? e.message : 'Fehler';
			setTimeout(() => (errorMsg = ''), 3000);
		} finally {
			busyWord = null;
		}
	}

	// Recent Chinese words from lexicon for empty state
	let recentWords = $derived(
		data.lexicon()
			.filter((e) => e.language === 'zh')
			.slice(0, 12)
	);

	// Default popular words to show before any search
	const defaultWords = ['你好', '谢谢', '学习', '中国', '朋友', '吃饭', '工作', '喜欢', '漂亮', '时间', '明天', '快乐'];

	function searchWord(word: string) {
		query = word;
		results = lookupCedict(word);
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
		<span class="material-symbols-outlined mr-3 text-[20px] text-primary/40">search</span>
		<input
			type="text"
			bind:value={query}
			oninput={handleInput}
			onkeydown={handleKeydown}
			class="min-w-0 flex-1 border-none bg-transparent p-0 text-base font-normal placeholder:text-primary/40 focus:ring-0"
			placeholder="Hanzi, Pinyin oder Englisch..."
		/>
		{#if query}
			<button
				onclick={() => {
					query = '';
					results = [];
				}}
				class="p-1 text-primary/40 hover:text-primary"
			>
				<span class="material-symbols-outlined text-[20px]">close</span>
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
			<span class="material-symbols-outlined mb-2 text-[32px] text-slate-300 dark:text-slate-500"
				>search_off</span
			>
			<p class="text-sm text-slate-500 dark:text-slate-400">
				Keine Ergebnisse f&uuml;r &laquo;{query.trim()}&raquo;
			</p>
		</div>
	{:else if results.length > 0}
		<h3 class="px-1 text-[11px] font-bold uppercase tracking-wider text-primary">
			{results.length} Ergebnis{results.length !== 1 ? 'se' : ''}
		</h3>

		{#each results as entry, i (entry.simplified + entry.pinyin + i)}
			<div
				class="rounded-2xl border border-slate-100 bg-white p-4 shadow-sm dark:border-white/5 dark:bg-slate-800/40"
			>
				<div class="flex items-start gap-3">
					<!-- Character + Pinyin -->
					<div class="min-w-0 flex-1">
						<div class="mb-1 flex flex-wrap items-baseline gap-2">
							<span class="text-2xl font-light">
								{#each splitChars(entry.simplified) as char}
									<a
										href="/character/{encodeURIComponent(char)}"
										class="chinese-char hover:text-primary">{char}</a
									>
								{/each}
								{#if splitChars(entry.simplified).length === 0}
									<span>{entry.simplified}</span>
								{/if}
							</span>
							<span class="text-sm text-primary/70">{entry.pinyin}</span>
						</div>
						<p class="text-[13px] leading-relaxed text-slate-600 dark:text-slate-400">
							{entry.english}
						</p>
					</div>

					<!-- Actions -->
					<div class="flex shrink-0 items-center gap-1">
						<button
							onclick={() => speak(entry.simplified, 'zh')}
							class="rounded-lg p-1.5 text-slate-300 transition-colors hover:bg-slate-100 hover:text-primary dark:text-slate-500 dark:hover:bg-white/10"
							title="Aussprechen"
						>
							<span class="material-symbols-outlined text-[20px]">volume_up</span>
						</button>
						<button
							onclick={() => handleToggle(entry)}
							disabled={busyWord === entry.simplified}
							class="rounded-lg p-1.5 transition-colors disabled:opacity-50 {lexiconMap.has(entry.simplified)
								? 'text-primary hover:bg-red-50 hover:text-red-500 dark:hover:bg-red-950'
								: 'text-slate-300 hover:bg-primary/10 hover:text-primary dark:text-slate-500 dark:hover:bg-primary/20'}"
							title={lexiconMap.has(entry.simplified) ? 'Aus Lexikon entfernen' : 'Zum Lexikon hinzuf\u00fcgen'}
						>
							<span class="material-symbols-outlined text-[20px]">
								{#if busyWord === entry.simplified}
									hourglass_empty
								{:else if lexiconMap.has(entry.simplified)}
									check_circle
								{:else}
									add_circle
								{/if}
							</span>
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
						<span class="chinese-char text-lg font-medium text-slate-900 dark:text-slate-100">{entry.word}</span>
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
					class="chinese-char rounded-full border border-slate-100 dark:border-white/5 bg-white dark:bg-white/5 px-4 py-2 text-lg shadow-sm transition-colors hover:bg-primary/5 text-slate-900 dark:text-slate-100"
				>
					{word}
				</button>
			{/each}
		</div>

		<div
			class="rounded-2xl border border-slate-100 bg-white p-8 text-center shadow-sm dark:border-white/5 dark:bg-white/5"
		>
			<span class="material-symbols-outlined mb-2 text-[32px] text-primary/30">dictionary</span>
			<p class="text-sm text-slate-500 dark:text-slate-400">
				Durchsuche CC-CEDICT mit 124.000 Eintr&auml;gen.
			</p>
			<p class="mt-1 text-xs text-slate-400 dark:text-slate-500">
				Suche nach Schriftzeichen, Pinyin oder Englisch.
			</p>
		</div>
	{/if}
</section>
