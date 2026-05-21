<script lang="ts">
	import Book from '$lib/icons/Book.svelte';
	import Close from '$lib/icons/Close.svelte';
	import Add from '$lib/icons/Add.svelte';
	import Check from '$lib/icons/Check.svelte';
	import { addWord, lookupWord, type DictResult, flattenDictResult } from '$lib/wasm';
	import { data } from '$lib/data.svelte';
	import { toastStore } from '$lib/toast.svelte';

	let text = $state('');
	let popup: {
		token: string;
		results: DictResult[];
		x: number;
		y: number;
		sentence: string;
	} | null = $state(null);

	// Words the user has already saved this session — drives the inline ✓ chip
	// so the same token can't be re-added by accident on a long page. Cleared
	// when the user blanks the textarea since they're starting a new doc.
	let savedThisSession = $state(new Set<string>());

	const SAMPLES: Array<{ label: string; text: string }> = [
		{
			label: 'Chinesisch (HSK 3)',
			text: '今天天气很好，我们一起去公园散步。妹妹喜欢吃苹果，但是哥哥更喜欢香蕉。',
		},
		{
			label: 'Deutsch',
			text: 'Die Sprache ist nicht nur ein Werkzeug der Kommunikation, sondern auch ein Spiegel der Kultur. Wer eine neue Sprache lernt, gewinnt ein neues Fenster zur Welt.',
		},
		{
			label: 'Englisch',
			text: 'Reading widely is the cheapest way to acquire vocabulary you can actually use. Pick a paragraph, tap unfamiliar words, save the ones worth keeping.',
		},
	];

	function isCjkChar(ch: string): boolean {
		const code = ch.codePointAt(0) ?? 0;
		return (
			(code >= 0x4e00 && code <= 0x9fff) ||
			(code >= 0x3400 && code <= 0x4dbf) ||
			(code >= 0x20000 && code <= 0x2a6df)
		);
	}

	// One "token" worth highlighting in the rendered text. CJK runs get
	// greedy-longest-match against CEDICT (so "你好" surfaces as a single
	// tappable token instead of two characters); Latin runs split on
	// whitespace/punctuation; everything else falls through as plain text
	// (`tappable: false`).
	interface Token {
		text: string;
		tappable: boolean;
		isCjk: boolean;
	}

	function tokenize(input: string): Token[] {
		const out: Token[] = [];
		const chars = [...input]; // codepoint-safe split
		let i = 0;
		while (i < chars.length) {
			const ch = chars[i];
			if (isCjkChar(ch)) {
				// Greedy longest-match — try 4, 3, 2 then fall back to 1 char.
				// 4 covers most CC-CEDICT multi-char entries; longer words exist
				// (chéngyǔ idioms etc.) but they're rare and not worth the lookup cost.
				let matched: string | null = null;
				for (let len = Math.min(4, chars.length - i); len >= 2; len--) {
					const candidate = chars.slice(i, i + len).join('');
					if (lookupWord(candidate).length > 0) {
						matched = candidate;
						break;
					}
				}
				if (matched) {
					out.push({ text: matched, tappable: true, isCjk: true });
					i += [...matched].length;
				} else {
					out.push({ text: ch, tappable: true, isCjk: true });
					i++;
				}
			} else if (/\p{L}/u.test(ch)) {
				// Walk through the Latin/word run greedily.
				let j = i;
				while (j < chars.length && /[\p{L}\p{M}'’-]/u.test(chars[j])) j++;
				const word = chars.slice(i, j).join('');
				out.push({ text: word, tappable: word.length >= 2, isCjk: false });
				i = j;
			} else {
				// Whitespace, punctuation, digits — keep as a non-tappable text run
				// so the rendered output preserves spacing/line breaks faithfully.
				let j = i;
				while (
					j < chars.length &&
					!isCjkChar(chars[j]) &&
					!/\p{L}/u.test(chars[j])
				) j++;
				out.push({ text: chars.slice(i, j).join(''), tappable: false, isCjk: false });
				i = j;
			}
		}
		return out;
	}

	let tokens = $derived(tokenize(text));

	function sentenceAround(target: string): string {
		// Walk back/forward from the first match of `target` to the nearest
		// sentence boundary so the saved card has surrounding context.
		// CJK sentence punctuation included (。！？) alongside Latin (.!?).
		const idx = text.indexOf(target);
		if (idx < 0) return '';
		const PUNCT = /[.!?。！？\n]/;
		let start = idx;
		while (start > 0 && !PUNCT.test(text[start - 1])) start--;
		let end = idx + target.length;
		while (end < text.length && !PUNCT.test(text[end])) end++;
		if (end < text.length) end++; // include the punctuation
		return text.slice(start, end).trim();
	}

	function openPopup(event: MouseEvent, token: Token) {
		if (!token.tappable) return;
		const el = event.currentTarget as HTMLElement;
		const rect = el.getBoundingClientRect();
		const results = lookupWord(token.text);
		popup = {
			token: token.text,
			results,
			x: rect.left + rect.width / 2,
			y: rect.bottom + 6,
			sentence: sentenceAround(token.text),
		};
	}

	function closePopup() {
		popup = null;
	}

	async function save(): Promise<void> {
		if (!popup) return;
		try {
			await addWord(popup.token);
			savedThisSession.add(popup.token);
			savedThisSession = new Set(savedThisSession);
			data.bump();
			toastStore.show(`«${popup.token}» zum Lexikon hinzugefügt`);
			closePopup();
		} catch (e) {
			toastStore.show(`Fehler: ${e instanceof Error ? e.message : 'unbekannt'}`);
		}
	}

	function loadSample(sample: string) {
		text = sample;
		savedThisSession = new Set();
		closePopup();
	}

	function clear() {
		text = '';
		savedThisSession = new Set();
		closePopup();
	}
</script>

<svelte:window onclick={(e) => {
	// Click anywhere outside the popup closes it. The popup itself stops propagation.
	if (popup) closePopup();
	void e;
}} />

<div class="space-y-5 py-4">
	<div>
		<p class="text-[11px] font-bold uppercase tracking-wider text-primary">Lesen</p>
		<p class="mt-1 text-sm text-slate-500 dark:text-slate-400">
			Text einfügen, Wörter antippen, mit einem Klick ins Lexikon speichern.
		</p>
	</div>

	<!-- Input -->
	<div class="space-y-3">
		<textarea
			bind:value={text}
			placeholder="Hier Text einfügen — Chinesisch, Deutsch oder Englisch."
			rows="6"
			class="w-full resize-y rounded-2xl border border-slate-200 bg-white px-4 py-3 text-base leading-relaxed text-slate-900 placeholder:text-slate-400 focus:border-primary focus:outline-none dark:border-white/10 dark:bg-white/5 dark:text-slate-100"
		></textarea>

		<div class="flex flex-wrap items-center gap-2">
			<span class="text-xs font-medium text-slate-400 dark:text-slate-500">Beispiel:</span>
			{#each SAMPLES as sample (sample.label)}
				<button
					type="button"
					onclick={() => loadSample(sample.text)}
					class="rounded-full border border-slate-200 bg-white px-3 py-1 text-xs font-medium text-slate-600 transition-colors hover:border-primary/30 hover:text-primary dark:border-white/10 dark:bg-white/5 dark:text-slate-300"
				>
					{sample.label}
				</button>
			{/each}
			{#if text}
				<button
					type="button"
					onclick={clear}
					class="ml-auto rounded-full px-3 py-1 text-xs font-medium text-slate-400 transition-colors hover:text-red-500 dark:text-slate-500"
				>
					Leeren
				</button>
			{/if}
		</div>
	</div>

	<!-- Rendered -->
	{#if text}
		<div class="rounded-2xl border border-slate-100 bg-white p-5 leading-loose dark:border-white/5 dark:bg-white/5">
			<p class="text-lg text-slate-900 dark:text-slate-100">
				{#each tokens as tok, i (i)}
					{#if tok.tappable}
						<!-- svelte-ignore a11y_click_events_have_key_events -->
						<!-- svelte-ignore a11y_no_static_element_interactions -->
						<span
							onclick={(e) => {
								e.stopPropagation();
								openPopup(e, tok);
							}}
							class="cursor-pointer rounded transition-colors hover:bg-primary/10 {savedThisSession.has(tok.text) ? 'bg-emerald-100 dark:bg-emerald-500/20' : ''}"
							>{tok.text}</span
						>
					{:else}
						<span>{tok.text}</span>
					{/if}
				{/each}
			</p>
			<p class="mt-3 text-xs text-slate-400 dark:text-slate-500">
				Tippe auf ein Wort für Übersetzung + Speichern. Chinesisch nutzt CC-CEDICT (längste Übereinstimmung), Latein/Deutsch nutzen Wiktextract.
			</p>
		</div>
	{:else}
		<div class="rounded-2xl border border-dashed border-slate-200 p-12 text-center dark:border-white/10">
			<div class="mx-auto mb-3 flex size-12 items-center justify-center rounded-full bg-primary/10">
				<Book class="text-primary" />
			</div>
			<p class="text-sm text-slate-500 dark:text-slate-400">
				Füge oben Text ein oder wähle ein Beispiel.
			</p>
		</div>
	{/if}
</div>

<!-- Lookup popup -->
{#if popup}
	<!-- svelte-ignore a11y_no_static_element_interactions -->
	<!-- svelte-ignore a11y_click_events_have_key_events -->
	<div
		onclick={(e) => e.stopPropagation()}
		class="fixed z-40 w-80 max-w-[calc(100vw-2rem)] rounded-2xl border border-slate-100 bg-white p-4 shadow-xl dark:border-white/10 dark:bg-slate-800"
		style="left: {Math.max(16, Math.min(window.innerWidth - 336, popup.x - 160))}px; top: {Math.min(window.innerHeight - 240, popup.y)}px;"
	>
		<div class="mb-2 flex items-start justify-between gap-3">
			<div class="min-w-0 flex-1">
				<p class="break-words text-2xl font-bold text-slate-900 dark:text-slate-100">
					{popup.token}
				</p>
			</div>
			<button
				type="button"
				onclick={closePopup}
				aria-label="Schließen"
				class="-mr-1 -mt-1 shrink-0 rounded-full p-1 text-slate-400 transition-colors hover:bg-slate-100 hover:text-slate-600 dark:hover:bg-white/10 dark:hover:text-slate-200"
			>
				<Close class="text-[16px]" />
			</button>
		</div>

		{#if popup.results.length > 0}
			<div class="max-h-48 overflow-y-auto rounded-xl bg-slate-50 p-3 dark:bg-white/5">
				{#each popup.results.slice(0, 3) as r (r.word)}
					<p class="text-sm leading-relaxed text-slate-700 dark:text-slate-200">
						{flattenDictResult(r)}
					</p>
				{/each}
				{#if popup.results.length > 3}
					<p class="mt-2 text-xs text-slate-400 dark:text-slate-500">
						+{popup.results.length - 3} weitere Einträge
					</p>
				{/if}
			</div>
		{:else}
			<p class="rounded-xl bg-slate-50 p-3 text-sm italic text-slate-500 dark:bg-white/5 dark:text-slate-400">
				Kein Wörterbucheintrag gefunden — du kannst es trotzdem speichern.
			</p>
		{/if}

		<button
			type="button"
			onclick={save}
			disabled={savedThisSession.has(popup.token)}
			class="mt-3 flex w-full items-center justify-center gap-2 rounded-xl bg-primary px-4 py-2.5 text-sm font-bold text-white transition-opacity hover:opacity-90 disabled:opacity-50"
		>
			{#if savedThisSession.has(popup.token)}
				<Check class="text-[16px]" />
				Bereits gespeichert
			{:else}
				<Add class="text-[16px]" />
				Zum Lexikon hinzufügen
			{/if}
		</button>
	</div>
{/if}
