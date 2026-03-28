<script lang="ts">
	import { onMount } from 'svelte';

	interface Props {
		days: Array<{ d: number; c: number; r: number }>;
	}

	let { days }: Props = $props();

	let container: HTMLDivElement | undefined = $state();

	// Build lookup map
	let dayMap = $derived(new Map(days.map((d) => [d.d, d.c])));

	const today = Math.floor(Date.now() / 86400000);
	const totalDays = 371; // 53 weeks * 7
	const startDay = today - totalDays + 1;

	// Align to Monday: find the Monday on or before startDay
	const startDow = ((new Date(startDay * 86400000).getDay() + 6) % 7); // 0=Mon
	const gridStart = startDay - startDow;
	const numCols = Math.ceil((today - gridStart + 1) / 7);

	function intensity(count: number): string {
		if (count === 0) return 'bg-slate-100 dark:bg-white/5';
		if (count <= 5) return 'bg-primary/20';
		if (count <= 15) return 'bg-primary/40';
		if (count <= 30) return 'bg-primary/70';
		return 'bg-primary';
	}

	// Build grid cells: column-first (each column = 1 week)
	let cells = $derived.by(() => {
		const result: Array<{ day: number; count: number; future: boolean }> = [];
		for (let col = 0; col < numCols; col++) {
			for (let row = 0; row < 7; row++) {
				const d = gridStart + col * 7 + row;
				result.push({
					day: d,
					count: dayMap.get(d) ?? 0,
					future: d > today,
				});
			}
		}
		return result;
	});

	// Month labels
	let monthLabels = $derived.by(() => {
		const labels: Array<{ col: number; label: string }> = [];
		const months = ['Jan', 'Feb', 'M\u00e4r', 'Apr', 'Mai', 'Jun', 'Jul', 'Aug', 'Sep', 'Okt', 'Nov', 'Dez'];
		let lastMonth = -1;
		for (let col = 0; col < numCols; col++) {
			const d = gridStart + col * 7;
			const date = new Date(d * 86400000);
			const m = date.getMonth();
			if (m !== lastMonth) {
				labels.push({ col, label: months[m] });
				lastMonth = m;
			}
		}
		return labels;
	});

	let totalReviews = $derived(days.reduce((s, d) => s + d.c, 0));

	function formatDate(epochDay: number): string {
		const date = new Date(epochDay * 86400000);
		return `${date.getDate()}.${date.getMonth() + 1}.${date.getFullYear()}`;
	}

	onMount(() => {
		if (container) {
			container.scrollLeft = container.scrollWidth;
		}
	});
</script>

<div class="rounded-xl border border-primary/10 bg-white p-4 shadow-sm dark:bg-white/5">
	<div class="mb-3 flex items-center justify-between">
		<p class="text-[11px] font-bold uppercase tracking-wider text-primary">Aktivit&auml;t</p>
		<p class="text-xs text-slate-400 dark:text-slate-500">{totalReviews} gesamt</p>
	</div>

	<!-- Month labels -->
	<div class="overflow-hidden">
		<div
			bind:this={container}
			class="overflow-x-auto no-scrollbar"
		>
			<!-- Month row -->
			<div
				class="mb-1 grid gap-[2px]"
				style="grid-template-columns: 20px repeat({numCols}, 10px); grid-template-rows: 14px;"
			>
				<div></div>
				{#each Array(numCols) as _, col (col)}
					{@const label = monthLabels.find((m) => m.col === col)}
					<div class="text-[9px] font-bold text-slate-400 dark:text-slate-500 leading-none">
						{label?.label ?? ''}
					</div>
				{/each}
			</div>

			<!-- Heatmap grid -->
			<div
				class="grid gap-[2px]"
				style="grid-template-columns: 20px repeat({numCols}, 10px); grid-template-rows: repeat(7, 10px);"
			>
				<!-- Day labels column -->
				{#each ['Mo', '', 'Mi', '', 'Fr', '', ''] as label, row (row)}
					<div
						class="flex items-center text-[9px] font-bold text-slate-400 dark:text-slate-500"
						style="grid-column: 1; grid-row: {row + 1};"
					>
						{label}
					</div>
				{/each}

				<!-- Data cells -->
				{#each cells as cell, idx (idx)}
					{@const col = Math.floor(idx / 7)}
					{@const row = idx % 7}
					<div
						class="rounded-[2px] {cell.future ? 'bg-transparent' : intensity(cell.count)}"
						style="grid-column: {col + 2}; grid-row: {row + 1};"
						title={cell.future ? '' : `${formatDate(cell.day)}: ${cell.count} Karten`}
					></div>
				{/each}
			</div>
		</div>
	</div>

	<!-- Legend -->
	<div class="mt-3 flex items-center justify-end gap-2 text-[10px] text-slate-400 dark:text-slate-500">
		<span>Weniger</span>
		<div class="flex gap-[2px]">
			<div class="size-[10px] rounded-[2px] bg-slate-100 dark:bg-white/5"></div>
			<div class="size-[10px] rounded-[2px] bg-primary/20"></div>
			<div class="size-[10px] rounded-[2px] bg-primary/40"></div>
			<div class="size-[10px] rounded-[2px] bg-primary/70"></div>
			<div class="size-[10px] rounded-[2px] bg-primary"></div>
		</div>
		<span>Mehr</span>
	</div>
</div>
