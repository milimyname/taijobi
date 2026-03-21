<script lang="ts">
	import { type Card, type DrillStats } from '$lib/wasm';
	import { data } from '$lib/data.svelte';

	let dueCount = $derived(data.dueCount());
	let previewCards: Card[] = $derived(data.dueCards(5));
	let stats: DrillStats = $derived(data.drillStats());

	function accuracy(s: DrillStats): string {
		if (s.reviewed_today === 0) return '—';
		return Math.round((s.correct_today / s.reviewed_today) * 100) + '%';
	}
</script>

<!-- Greeting -->
<section class="mb-6 mt-4">
	<h1 class="text-3xl font-bold tracking-tight text-slate-900 dark:text-slate-100">Guten Morgen</h1>
</section>

<!-- Hero Card -->
{#if dueCount > 0}
	<section class="mb-8">
		<div class="relative overflow-hidden rounded-xl bg-primary p-6 shadow-lg shadow-primary/20">
			<div class="absolute right-0 top-0 p-4 opacity-10">
				<span class="material-symbols-outlined text-8xl rotate-12 text-white">auto_stories</span>
			</div>
			<div class="relative z-10">
				<h2 class="mb-1 text-4xl font-bold text-white">{dueCount} Karten f&auml;llig</h2>
				<p class="mb-6 text-sm font-medium text-white/80">
					Gesch&auml;tzte Zeit: {Math.max(1, Math.round(dueCount * 0.5))} Min.
				</p>
				<a
					href="/drill"
					class="inline-flex items-center gap-2 rounded-lg bg-white dark:bg-white/5 px-6 py-3 text-sm font-bold text-primary transition-colors hover:bg-slate-100 dark:hover:bg-white/10"
				>
					Lernen starten
					<span class="material-symbols-outlined text-sm">play_arrow</span>
				</a>
			</div>
		</div>
	</section>
{:else}
	<section class="mb-8">
		<div class="rounded-xl border border-primary/10 bg-white dark:bg-white/5 p-8 text-center shadow-sm">
			<p class="text-2xl font-bold text-slate-900 dark:text-slate-100">Alles erledigt!</p>
			<p class="mt-2 text-sm text-slate-500 dark:text-slate-400">Keine Karten f&auml;llig. Komm sp&auml;ter wieder.</p>
		</div>
	</section>
{/if}

<!-- Today Stats -->
<section class="mb-8">
	<div class="flex items-center justify-between mb-4">
		<h3 class="text-lg font-bold text-slate-900 dark:text-slate-100">Heute</h3>
		{#if stats.reviewed_today > 0}
			<span class="text-xs font-bold uppercase tracking-wider text-primary">
				{accuracy(stats)} Genauigkeit
			</span>
		{/if}
	</div>
	<div
		class="flex items-center justify-between rounded-xl border border-primary/10 bg-white dark:bg-white/5 p-4"
	>
		<div class="flex gap-2">
			{#each Array(Math.min(stats.reviewed_today, 7)) as _, i (i)}
				<div class="size-3 rounded-full bg-primary"></div>
			{/each}
			{#each Array(Math.max(0, 7 - Math.min(stats.reviewed_today, 7))) as _, i (i)}
				<div class="size-3 rounded-full bg-primary/10"></div>
			{/each}
		</div>
		<p class="text-sm text-slate-500 dark:text-slate-400">{stats.reviewed_today} / {stats.total_cards} gelernt</p>
	</div>
</section>

<!-- Textbook / Pack Progress -->
<section class="mb-8">
	<div class="flex items-center justify-between mb-4">
		<h3 class="text-lg font-bold text-slate-900 dark:text-slate-100">Deine Lehrb&uuml;cher</h3>
	</div>
	<div
		class="flex items-center gap-4 rounded-xl border border-primary/5 bg-white dark:bg-white/5 p-4 shadow-sm"
	>
		<div class="flex size-16 shrink-0 items-center justify-center rounded-lg bg-primary/5">
			<span class="material-symbols-outlined text-3xl text-primary">menu_book</span>
		</div>
		<div class="flex-1">
			<div class="mb-1 flex items-start justify-between">
				<div>
					<h4 class="font-bold text-slate-900 dark:text-slate-100">L&oacute;ng neu</h4>
					<p class="text-xs font-medium text-slate-500 dark:text-slate-400">Lektion 5</p>
				</div>
				<span class="rounded-full bg-primary/10 px-2 py-0.5 text-xs font-bold text-primary"
					>L5</span
				>
			</div>
			<div class="mt-3">
				<div class="mb-1 flex justify-between text-[10px] font-bold text-slate-400 dark:text-slate-500">
					<span>FORTSCHRITT</span>
					<span>{Math.round((stats.reviewed_today / Math.max(stats.total_cards, 1)) * 100)}%</span>
				</div>
				<div class="h-1.5 w-full overflow-hidden rounded-full bg-slate-100 dark:bg-white/10">
					<div
						class="h-full rounded-full bg-primary"
						style="width: {(stats.reviewed_today / Math.max(stats.total_cards, 1)) * 100}%"
					></div>
				</div>
			</div>
		</div>
	</div>
</section>

<!-- Recent Words -->
{#if previewCards.length > 0}
	<section class="mb-8">
		<h3 class="mb-4 text-lg font-bold text-slate-900 dark:text-slate-100">Zuletzt gelernte W&ouml;rter</h3>
		<div class="flex flex-wrap gap-2">
			{#each previewCards.slice(0, 5) as card (card.id)}
				<div
					class="rounded-full border border-primary/5 bg-white dark:bg-white/5 px-4 py-2 shadow-sm"
				>
					<span class="font-medium text-slate-900 dark:text-slate-100" class:chinese-char={card.language === 'zh'}
						>{card.word}</span
					>
					{#if card.pinyin}
						<span class="ml-2 text-sm text-slate-400 dark:text-slate-500">{card.pinyin}</span>
					{/if}
				</div>
			{/each}
		</div>
	</section>
{/if}

<!-- Lexicon Link -->
{#if stats.lexicon_count > 0}
	<section class="mb-8">
		<a
			href="/lexicon"
			class="flex items-center justify-between rounded-xl border border-primary/10 bg-white dark:bg-white/5 p-4 shadow-sm transition-colors hover:bg-primary/5"
		>
			<div class="flex items-center gap-3">
				<span class="material-symbols-outlined text-primary">book</span>
				<div>
					<p class="font-bold text-slate-900 dark:text-slate-100">Lexikon</p>
					<p class="text-xs text-slate-500 dark:text-slate-400">{stats.lexicon_count} W&ouml;rter gesammelt</p>
				</div>
			</div>
			<span class="material-symbols-outlined text-slate-400 dark:text-slate-500">chevron_right</span>
		</a>
	</section>
{/if}
