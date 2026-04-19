<script lang="ts">
	import Download from '$lib/icons/Download.svelte';
	import PlayArrow from '$lib/icons/PlayArrow.svelte';
	import Sync from '$lib/icons/Sync.svelte';
	import VolumeUp from '$lib/icons/VolumeUp.svelte';
	import { page } from '$app/state';
	import {
		decompose,
		getStrokes,
		lookupCedict,
		getLexicon,
		isChineseDataLoaded,
		type DecompResult,
		type StrokeData,
		type DecompComponent,
		type LexiconEntry,
	} from '$lib/wasm';
	import { speak } from '$lib/speak';
	import { downloadAndLoad } from '$lib/dictionary-data';
	import { data } from '$lib/data.svelte';
	import { toastStore } from '$lib/toast.svelte';
	import { recentCharsStore } from '$lib/recent-chars.svelte';
	import { untrack } from 'svelte';

	let char = $derived(decodeURIComponent(page.params.char ?? ''));

	// Track visits for the ⌘K "Kürzlich" section. untrack() keeps the
	// effect from depending on recentCharsStore.chars (which visit() reads
	// internally to dedupe — without untrack, the write triggers the
	// effect again and we get effect_update_depth_exceeded).
	$effect(() => {
		const c = char;
		if (c) untrack(() => recentCharsStore.visit(c));
	});
	let decompData: DecompResult | null = $state(null);
	let strokeData: StrokeData | null = $state(null);
	let relatedWords: LexiconEntry[] = $state([]);
	let animating = $state(false);
	let animationFrame = $state(-1);
	let downloading = $state(false);
	let hasChineseData = $derived(data.chineseDataLoaded());

	async function downloadData(): Promise<void> {
		if (downloading) return;
		downloading = true;
		try {
			await downloadAndLoad();
			data.bump();
			toastStore.show('Chinesische Daten geladen');
		} catch (e) {
			toastStore.show(`Download fehlgeschlagen: ${e instanceof Error ? e.message : 'Fehler'}`);
		} finally {
			downloading = false;
		}
	}

	$effect(() => {
		if (!char) return;
		decompData = decompose(char);
		strokeData = getStrokes(char);

		// Find words containing this character in user's lexicon
		const allWords = getLexicon();
		relatedWords = allWords.filter((w) => w.word.includes(char));
	});

	function playAnimation() {
		if (!strokeData || animating) return;
		animating = true;
		animationFrame = 0;
		const interval = setInterval(() => {
			animationFrame++;
			if (animationFrame >= strokeData!.stroke_count) {
				clearInterval(interval);
				animating = false;
			}
		}, 600);
	}

	function componentLabel(type: string): string {
		switch (type) {
			case 'radical':
				return 'Radikal';
			default:
				return 'Komponente';
		}
	}

	function strokeViewBox(): string {
		return '0 0 1024 1024';
	}
</script>

<section class="mt-4">
	<!-- Breadcrumb -->
	<div class="mb-4 flex items-center gap-2 text-sm text-slate-500 dark:text-slate-400">
		<a href="/home" class="hover:text-primary">Lernen</a>
		<span>&rsaquo;</span>
		<span class="font-medium text-slate-900 dark:text-slate-100">{char}</span>
	</div>

	<!-- Hero Section -->
	<div class="rounded-2xl border border-slate-100 dark:border-white/5 bg-[#fdfaf3] dark:bg-slate-800/60 p-6 shadow-sm">
		<div class="flex items-start justify-between">
			<div class="flex-1 text-center">
				<h1 class="chinese-char text-[96px] font-light leading-none text-slate-900 dark:text-slate-100">
					{char}
				</h1>
				{#if decompData}
					<p class="mt-2 text-lg font-medium text-primary dark:text-accent">{decompData.pinyin}</p>
					<p class="mt-1 text-sm text-slate-600 dark:text-slate-300">{decompData.definition}</p>
				{/if}
			</div>
			<button
				onclick={() => speak(char, 'zh')}
				class="flex items-center justify-center rounded-full bg-primary/10 p-2 text-primary transition-colors hover:bg-primary/20"
			>
				<VolumeUp class="text-xl" />
			</button>
		</div>
	</div>
</section>

<!-- Download prompt when Chinese data not loaded -->
{#if !decompData && !strokeData && !hasChineseData}
	<section class="mt-6">
		<div class="rounded-2xl border border-dashed border-slate-200 bg-slate-50 p-6 text-center dark:border-white/10 dark:bg-white/5">
			<Download class="text-4xl text-slate-300 dark:text-slate-600" />
			<p class="mt-2 text-sm font-medium text-slate-600 dark:text-slate-300">
				Chinesische Daten nicht geladen
			</p>
			<p class="mt-1 text-xs text-slate-400 dark:text-slate-500">
				Für Zerlegung, Strichfolge und Wörterbuch (~8 MB).
			</p>
			<button
				onclick={downloadData}
				disabled={downloading}
				class="mt-4 inline-flex items-center gap-2 rounded-xl bg-primary px-5 py-2.5 text-sm font-bold text-white shadow-sm transition-colors hover:bg-primary/90 disabled:opacity-50"
			>
				{#if downloading}
					<Sync class="animate-spin text-[18px]" />
					Herunterladen…
				{:else}
					<Download class="text-[18px]" />
					Herunterladen
				{/if}
			</button>
		</div>
	</section>
{/if}

<!-- Components Section -->
{#if decompData && decompData.components.length > 0}
	<section class="mt-6">
		<h3 class="mb-3 text-[11px] font-bold uppercase tracking-wider text-primary">
			Komponenten
		</h3>
		{#if decompData.decomposition}
			<p class="mb-3 text-sm text-slate-500 dark:text-slate-400">
				Zerlegung: <span class="font-mono text-slate-700 dark:text-slate-200">{decompData.decomposition}</span>
			</p>
		{/if}
		<div class="flex flex-wrap gap-3">
			{#each decompData.components as comp (comp.char)}
				<a
					href="/character/{encodeURIComponent(comp.char)}"
					class="flex min-w-[80px] flex-col items-center rounded-xl border border-slate-100 dark:border-white/5 bg-white dark:bg-white/5 p-3 shadow-sm transition-colors hover:border-primary/20 hover:bg-primary/5"
				>
					<span class="chinese-char text-2xl {comp.type === 'radical' ? 'text-primary dark:text-accent' : 'text-slate-900 dark:text-slate-100'}">
						{comp.char}
					</span>
					<span class="mt-1 text-[10px] font-bold uppercase tracking-wider {comp.type === 'radical' ? 'text-primary dark:text-accent' : 'text-slate-400 dark:text-slate-500'}">
						{componentLabel(comp.type)}
					</span>
					{#if comp.definition}
						<span class="mt-0.5 text-center text-xs text-slate-500 dark:text-slate-400">
							{comp.definition.length > 30 ? comp.definition.slice(0, 30) + '...' : comp.definition}
						</span>
					{/if}
				</a>
			{/each}
		</div>
		{#if decompData.etymology_hint}
			<p class="mt-3 text-sm text-slate-500 dark:text-slate-400">
				<span class="font-medium text-slate-600 dark:text-slate-300">{decompData.etymology_type}:</span>
				{decompData.etymology_hint}
			</p>
		{/if}
	</section>
{/if}

<!-- Stroke Order Section -->
{#if strokeData}
	<section class="mt-6">
		<h3 class="mb-3 text-[11px] font-bold uppercase tracking-wider text-primary">
			Strichfolge
		</h3>
		<div class="rounded-2xl border border-slate-100 dark:border-white/5 bg-white dark:bg-white/5 p-4 shadow-sm">
			<div class="mx-auto flex max-w-[200px] items-center justify-center">
				<svg viewBox={strokeViewBox()} class="stroke-canvas h-[200px] w-[200px]">
					<!-- Crosshair guides — theme-aware via `guide` class → currentColor -->
					<g class="guide text-slate-200 dark:text-white/10" stroke="currentColor">
						<line x1="512" y1="0" x2="512" y2="1024" stroke-width="1" stroke-dasharray="8,8" />
						<line x1="0" y1="512" x2="1024" y2="512" stroke-width="1" stroke-dasharray="8,8" />
						<line x1="0" y1="0" x2="1024" y2="1024" stroke-width="0.5" stroke-dasharray="8,8" />
						<line x1="1024" y1="0" x2="0" y2="1024" stroke-width="0.5" stroke-dasharray="8,8" />
						<rect x="2" y="2" width="1020" height="1020" fill="none" stroke-width="2" stroke-dasharray="8,8" rx="4" />
					</g>

					<!-- Strokes (flipped: Make Me a Hanzi uses Y-up, SVG uses Y-down).
						 fill="currentColor" → pick up `stroke-*` classes so dark mode
						 uses the brighter accent instead of dark jade on dark bg. -->
					<g transform="scale(1,-1) translate(0,-1024)">
						{#each strokeData.strokes as stroke, i}
							<path
								d={stroke}
								fill="currentColor"
								stroke="none"
								class="transition-all duration-300 {animating
									? i < animationFrame
										? 'text-primary dark:text-accent'
										: i === animationFrame
											? 'text-accent'
											: 'text-slate-200 dark:text-white/10'
									: 'text-primary dark:text-accent'}"
							/>
						{/each}
					</g>
				</svg>
			</div>

			<div class="mt-3 flex items-center justify-center gap-3">
				<button
					onclick={playAnimation}
					disabled={animating}
					class="flex items-center gap-1.5 rounded-lg bg-primary px-4 py-2 text-sm font-medium text-white transition-colors hover:bg-primary/90 disabled:opacity-50"
				>
					<PlayArrow class="text-[18px]" />
					Animation
				</button>
				<span class="text-sm text-slate-500 dark:text-slate-400">{strokeData.stroke_count} Striche</span>
			</div>
		</div>
	</section>
{/if}

<!-- Related Words in Vocabulary -->
{#if relatedWords.length > 0}
	<section class="mt-6">
		<h3 class="mb-3 text-[11px] font-bold uppercase tracking-wider text-primary">
			In deinem Vokabular
		</h3>
		<div class="space-y-2">
			{#each relatedWords as word (word.id)}
				<div class="flex items-center justify-between rounded-xl border border-slate-100 dark:border-white/5 bg-white dark:bg-white/5 px-4 py-3 shadow-sm">
					<div>
						<span class="chinese-char text-lg font-medium text-slate-900 dark:text-slate-100">{word.word}</span>
						{#if word.pinyin}
							<span class="ml-2 text-sm text-primary/80 dark:text-accent">{word.pinyin}</span>
						{/if}
						{#if word.translation}
							<span class="ml-2 text-sm text-slate-500 dark:text-slate-400">{word.translation}</span>
						{/if}
					</div>
					<div class="flex items-center gap-2">
						{#if word.reps > 0}
							<span class="text-xs text-slate-400 dark:text-slate-500">{word.reps}x</span>
						{/if}
						<button
							onclick={() => speak(word.word, 'zh')}
							class="text-primary/40 hover:text-primary"
						>
							<VolumeUp class="text-[18px]" />
						</button>
					</div>
				</div>
			{/each}
		</div>
	</section>
{/if}

<!-- Bottom padding -->
<div class="h-8"></div>
