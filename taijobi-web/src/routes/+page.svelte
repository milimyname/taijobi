<script lang="ts">
	import { type Card, type DrillStats, type StatsData } from '$lib/wasm';
	import { data } from '$lib/data.svelte';

	let dueCount = $derived(data.dueCount());
	let previewCards: Card[] = $derived(data.dueCards(5));
	let stats: DrillStats = $derived(data.drillStats());

	const periods = [
		{ label: '7T', days: 7 },
		{ label: '14T', days: 14 },
		{ label: '30T', days: 30 }
	] as const;
	let selectedPeriod = $state(30);
	let statsData: StatsData = $derived(data.stats(selectedPeriod));

	function accuracy(s: DrillStats): string {
		if (s.reviewed_today === 0) return '—';
		return Math.round((s.correct_today / s.reviewed_today) * 100) + '%';
	}

	// Build full day array with gaps filled as zeros
	function buildDayBars(sd: StatsData, numDays: number): Array<{ d: number; c: number; r: number }> {
		if (sd.days.length === 0) return Array.from({ length: numDays }, () => ({ d: 0, c: 0, r: 0 }));
		const today = Math.floor(Date.now() / 86400000);
		const map = new Map(sd.days.map((d) => [d.d, d]));
		return Array.from({ length: numDays }, (_, i) => {
			const day = today - numDays + 1 + i;
			return map.get(day) ?? { d: day, c: 0, r: 0 };
		});
	}

	let dayBars = $derived(buildDayBars(statsData, selectedPeriod));
	let maxCount = $derived(Math.max(1, ...dayBars.map((d) => d.c)));

	const ratingLabels = ['Nochmal', 'Schwer', 'Gut', 'Einfach'];
	const ratingColors = ['bg-red-500', 'bg-amber-500', 'bg-green-500', 'bg-primary'];
	const ratingColorsDark = [
		'dark:bg-red-400',
		'dark:bg-amber-400',
		'dark:bg-green-400',
		'dark:bg-primary'
	];
	let totalRatings = $derived(statsData.ratings.reduce((a, b) => a + b, 0));

	// Tooltip state for bar chart
	let hoveredBar = $state<{ idx: number; x: number; y: number } | null>(null);

	function formatDayLabel(epochDay: number): string {
		const date = new Date(epochDay * 86400000);
		return `${date.getDate()}.${date.getMonth() + 1}.`;
	}

	function handleBarHover(e: PointerEvent | FocusEvent, idx: number) {
		hoveredBar = { idx, x: 0, y: 0 };
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

<!-- Statistik -->
<section class="mb-8">
	<div class="mb-4 flex items-center justify-between">
		<h3 class="text-lg font-bold text-slate-900 dark:text-slate-100">Statistik</h3>
		<div class="flex gap-1 rounded-lg bg-slate-100 p-0.5 dark:bg-white/10">
			{#each periods as p (p.days)}
				<button
					class="rounded-md px-2.5 py-1 text-xs font-bold transition-colors {selectedPeriod === p.days ? 'bg-white text-primary shadow-sm dark:bg-slate-700 dark:text-slate-100' : 'text-slate-500 hover:text-slate-700 dark:text-slate-400 dark:hover:text-slate-200'}"
					onclick={() => (selectedPeriod = p.days)}
				>
					{p.label}
				</button>
			{/each}
		</div>
	</div>

	<!-- Streak Card -->
	<div class="mb-4 flex items-center gap-3 rounded-xl border border-primary/10 bg-white p-4 shadow-sm dark:bg-white/5">
		<span class="material-symbols-outlined text-2xl text-amber-500">local_fire_department</span>
		<div>
			<p class="text-lg font-bold text-slate-900 dark:text-slate-100">{statsData.streak} Tage Streak</p>
			<p class="text-xs text-slate-500 dark:text-slate-400">L&auml;ngster: {statsData.longest_streak} Tage</p>
		</div>
	</div>

	<!-- Reviews Bar Chart -->
	<!-- svelte-ignore a11y_no_static_element_interactions -->
	<div class="relative mb-4 rounded-xl border border-primary/10 bg-white p-4 shadow-sm dark:bg-white/5" onpointerleave={() => (hoveredBar = null)}>
		<div class="mb-3 flex items-center justify-between">
			<p class="text-[11px] font-bold uppercase tracking-wider text-primary">Wiederholungen</p>
			<p class="text-xs text-slate-400 dark:text-slate-500">{dayBars.reduce((s, d) => s + d.c, 0)} gesamt</p>
		</div>
		<div class="flex items-end gap-px" style="height: 88px;">
			{#each dayBars as bar, i (i)}
				{@const pct = bar.c > 0 ? Math.max(6, Math.round((bar.c / maxCount) * 80)) : 0}
				{@const accPct = bar.c > 0 ? Math.round((bar.r / bar.c) * 100) : 0}
				<button
					class="relative flex-1 cursor-default rounded-t-sm transition-opacity {bar.c > 0 ? 'bg-primary' : 'bg-primary/10'} {hoveredBar && hoveredBar.idx !== i ? 'opacity-40' : ''}"
					style="height: {pct}px; min-width: 0;"
					onpointerenter={(e) => handleBarHover(e, i)}
					onfocus={(e) => handleBarHover(e, i)}
					tabindex="-1"
				>
					{#if bar.c > 0 && accPct < 100}
						<div
							class="absolute bottom-0 left-0 right-0 rounded-t-sm bg-red-400/30 dark:bg-red-400/20"
							style="height: {Math.round(((bar.c - bar.r) / bar.c) * pct)}px;"
						></div>
					{/if}
				</button>
			{/each}
		</div>
		<!-- Accuracy Trend Line -->
		{#if dayBars.some((d) => d.c > 0)}
			{@const barW = 100 / dayBars.length}
			<svg class="mt-1 w-full overflow-visible" viewBox="0 0 100 24" preserveAspectRatio="none" style="height: 24px;">
				<polyline
					fill="none"
					stroke="#52b788"
					stroke-width="0.8"
					stroke-linecap="round"
					stroke-linejoin="round"
					vector-effect="non-scaling-stroke"
					points="{dayBars.map((d, i) => {
						const acc = d.c > 0 ? (d.r / d.c) * 100 : -1;
						return acc >= 0 ? `${i * barW + barW / 2},${22 - (acc / 100) * 20}` : '';
					}).filter(Boolean).join(' ')}"
				/>
			</svg>
			<div class="mt-1 flex justify-between text-[10px] text-slate-400 dark:text-slate-500">
				<span>{formatDayLabel(dayBars[0].d)}</span>
				<span class="italic">Genauigkeit</span>
				<span>Heute</span>
			</div>
		{/if}
		<!-- Tooltip -->
		{#if hoveredBar}
			{@const bar = dayBars[hoveredBar.idx]}
			{@const accPct = bar.c > 0 ? Math.round((bar.r / bar.c) * 100) : 0}
			{@const leftPct = ((hoveredBar.idx + 0.5) / dayBars.length) * 100}
			<div
				class="pointer-events-none absolute top-0 z-20 -translate-x-1/2 -translate-y-full"
				style="left: {leftPct}%;"
			>
				<div class="mb-1 whitespace-nowrap rounded-lg bg-slate-800 px-3 py-1.5 text-center text-xs text-white shadow-lg dark:bg-slate-700">
					<p class="font-bold">{bar.c} Karten</p>
					{#if bar.c > 0}
						<p class="text-white/70">{accPct}% richtig</p>
					{/if}
					<p class="text-white/50">{formatDayLabel(bar.d)}</p>
				</div>
			</div>
		{/if}
	</div>

	<!-- Rating Distribution -->
	<div class="rounded-xl border border-primary/10 bg-white p-4 shadow-sm dark:bg-white/5">
		<p class="mb-3 text-[11px] font-bold uppercase tracking-wider text-primary">Bewertungen</p>
		<div class="space-y-2">
			{#each ratingLabels as label, i (label)}
				{@const count = statsData.ratings[i]}
				{@const pct = totalRatings > 0 ? (count / totalRatings) * 100 : 0}
				<div class="flex items-center gap-3">
					<span class="w-16 text-xs font-medium text-slate-600 dark:text-slate-400">{label}</span>
					<div class="h-2 flex-1 overflow-hidden rounded-full bg-slate-100 dark:bg-white/10">
						<div class="{ratingColors[i]} {ratingColorsDark[i]} h-full rounded-full" style="width: {pct}%;"></div>
					</div>
					<span class="w-8 text-right text-xs font-bold text-slate-500 dark:text-slate-400">{count}</span>
				</div>
			{/each}
		</div>
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
