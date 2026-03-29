<script lang="ts">
	import { type DrillStats, type StatsData } from '$lib/wasm';
	import { data } from '$lib/data.svelte';
	import Heatmap from '../../../components/Heatmap.svelte';

	let stats: DrillStats = $derived(data.drillStats());

	const periods = [
		{ label: '7T', days: 7 },
		{ label: '14T', days: 14 },
		{ label: '30T', days: 30 }
	] as const;
	let selectedPeriod = $state(30);
	let statsData: StatsData = $derived(data.stats(selectedPeriod));
	let heatmapData = $derived(data.stats(365));

	function accuracy(s: DrillStats): string {
		if (s.reviewed_today === 0) return '\u2014';
		return Math.round((s.correct_today / s.reviewed_today) * 100) + '%';
	}

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

	let hoveredBar = $state<{ idx: number; x: number; y: number } | null>(null);

	function formatDayLabel(epochDay: number): string {
		const date = new Date(epochDay * 86400000);
		return `${date.getDate()}.${date.getMonth() + 1}.`;
	}

	function handleBarHover(e: PointerEvent | FocusEvent, idx: number) {
		hoveredBar = { idx, x: 0, y: 0 };
	}

	let hasData = $derived(statsData.days.length > 0 || stats.reviewed_today > 0);
</script>

{#if !hasData}
	<!-- Empty state -->
	<div class="flex flex-col items-center pt-20">
		<div class="flex size-16 items-center justify-center rounded-full bg-primary/10">
			<span class="material-symbols-outlined text-[32px] text-primary">bar_chart</span>
		</div>
		<p class="mt-4 text-2xl font-bold text-slate-900 dark:text-slate-100">Noch keine Daten</p>
		<p class="mt-2 text-center text-sm text-slate-500 dark:text-slate-400">
			Starte eine &Uuml;bungsrunde, um deine Statistiken zu sehen.
		</p>
		<a
			href="/drill"
			class="mt-8 inline-flex items-center gap-2 rounded-xl bg-primary px-6 py-3 font-bold text-white shadow-md shadow-primary/20 transition-all hover:bg-primary/90"
		>
			<span class="material-symbols-outlined text-lg">play_arrow</span>
			Lernen starten
		</a>
	</div>
{:else}
	<!-- Summary Cards -->
	<section class="mb-6 mt-4 grid grid-cols-2 gap-3">
		<!-- Streak -->
		<div class="rounded-xl border border-primary/10 bg-white p-4 shadow-sm dark:bg-white/5">
			<div class="mb-2 flex items-center gap-2">
				<span class="material-symbols-outlined text-xl text-amber-500">local_fire_department</span>
				<span class="text-[11px] font-bold uppercase tracking-wider text-slate-400 dark:text-slate-500">Streak</span>
			</div>
			<p class="text-3xl font-bold text-slate-900 dark:text-slate-100">{statsData.streak}</p>
			<p class="text-xs text-slate-500 dark:text-slate-400">Tage &middot; L&auml;ngster: {statsData.longest_streak}</p>
		</div>

		<!-- Today -->
		<div class="rounded-xl border border-primary/10 bg-white p-4 shadow-sm dark:bg-white/5">
			<div class="mb-2 flex items-center gap-2">
				<span class="material-symbols-outlined text-xl text-primary">today</span>
				<span class="text-[11px] font-bold uppercase tracking-wider text-slate-400 dark:text-slate-500">Heute</span>
			</div>
			<p class="text-3xl font-bold text-slate-900 dark:text-slate-100">{stats.reviewed_today}</p>
			<p class="text-xs text-slate-500 dark:text-slate-400">
				von {stats.total_cards} &middot; {accuracy(stats)}
			</p>
		</div>
	</section>

	<!-- Bar Chart -->
	<section class="mb-6">
		<div class="mb-4 flex items-center justify-between">
			<h3 class="text-[11px] font-bold uppercase tracking-wider text-primary">Wiederholungen</h3>
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

		<!-- svelte-ignore a11y_no_static_element_interactions -->
		<div class="relative rounded-xl border border-primary/10 bg-white p-4 shadow-sm dark:bg-white/5" onpointerleave={() => (hoveredBar = null)}>
			<div class="mb-3 flex items-center justify-between">
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
	</section>

	<!-- Rating Distribution -->
	<section class="mb-6">
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

	<!-- Activity Heatmap -->
	<section class="mb-6">
		<Heatmap days={heatmapData.days} />
	</section>

	<!-- Totals -->
	<section class="mb-8">
		<div class="grid grid-cols-3 gap-3">
			<div class="rounded-xl border border-primary/10 bg-white p-3 text-center shadow-sm dark:bg-white/5">
				<p class="text-xl font-bold text-slate-900 dark:text-slate-100">{stats.total_cards}</p>
				<p class="text-[10px] font-bold uppercase tracking-wider text-slate-400 dark:text-slate-500">Karten</p>
			</div>
			<div class="rounded-xl border border-primary/10 bg-white p-3 text-center shadow-sm dark:bg-white/5">
				<p class="text-xl font-bold text-slate-900 dark:text-slate-100">{stats.lexicon_count}</p>
				<p class="text-[10px] font-bold uppercase tracking-wider text-slate-400 dark:text-slate-500">Lexikon</p>
			</div>
			<div class="rounded-xl border border-primary/10 bg-white p-3 text-center shadow-sm dark:bg-white/5">
				<p class="text-xl font-bold text-slate-900 dark:text-slate-100">{statsData.longest_streak}</p>
				<p class="text-[10px] font-bold uppercase tracking-wider text-slate-400 dark:text-slate-500">Bester Streak</p>
			</div>
		</div>
	</section>
{/if}
