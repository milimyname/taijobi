<script lang="ts">
	import Book from '$lib/icons/Book.svelte';
	import ChevronRight from '$lib/icons/ChevronRight.svelte';
	import PlayArrow from '$lib/icons/PlayArrow.svelte';
	import Shuffle from '$lib/icons/Shuffle.svelte';
	import Icon from '$lib/icons/Icon.svelte';
	import { type Card, type DrillStats, type Pack } from '$lib/wasm';
	import { data } from '$lib/data.svelte';

	let dueCount = $derived(data.dueCount());
	let previewCards: Card[] = $derived(data.dueCards(5));
	let stats: DrillStats = $derived(data.drillStats());
	let packs: Pack[] = $derived(data.packs());

	interface DrillSource {
		id: string;
		label: string;
		icon: string;
		due: number;
		unread: number;
	}

	let drillSources = $derived.by(() => {
		const sources: DrillSource[] = [];
		for (const pack of packs) {
			const due = data.dueCountFiltered(pack.id);
			const unread = data.unreadCount(pack.id);
			if (due > 0 || unread > 0) {
				sources.push({ id: pack.id, label: pack.name, icon: 'inventory_2', due, unread });
			}
		}
		const lexDue = data.dueCountFiltered('lexicon');
		const lexUnread = data.unreadCount('lexicon');
		if (lexDue > 0 || lexUnread > 0) {
			sources.push({ id: 'lexicon', label: 'Lexikon', icon: 'book', due: lexDue, unread: lexUnread });
		}
		return sources;
	});

	function accuracy(s: DrillStats): string {
		if (s.reviewed_today === 0) return '\u2014';
		return Math.round((s.correct_today / s.reviewed_today) * 100) + '%';
	}
</script>

<!-- Greeting -->
<section class="mb-6 mt-4">
	<h1 class="text-3xl font-bold tracking-tight text-slate-900 dark:text-slate-100">Guten Morgen</h1>
</section>

<!-- Drill Sources -->
{#if drillSources.length > 0}
	<section class="mb-8">
		<div class="grid grid-cols-1 gap-3 lg:grid-cols-2">
			{#each drillSources as source (source.id)}
				<a
					href="/drill?pack={encodeURIComponent(source.id)}"
					class="flex items-center gap-4 rounded-xl border border-slate-100 bg-white p-4 shadow-sm transition-colors hover:bg-primary/5 dark:border-white/5 dark:bg-white/5"
				>
					<div class="flex size-12 shrink-0 items-center justify-center rounded-lg bg-primary/10">
						<Icon name={source.icon} class="text-2xl text-primary" />
					</div>
					<div class="flex-1">
						<h3 class="font-bold text-slate-900 dark:text-slate-100">{source.label}</h3>
						<p class="text-xs text-slate-500 dark:text-slate-400">
							{#if source.due > 0 && source.unread > 0}
								{source.due} f&auml;llig &middot; {source.unread} neu
							{:else if source.due > 0}
								{source.due} Karten f&auml;llig
							{:else}
								{source.unread} neue W&ouml;rter
							{/if}
							&middot; ~{Math.max(1, Math.round((source.due + source.unread) * 0.5))} Min.
						</p>
					</div>
					<PlayArrow class="text-primary" />
				</a>
			{/each}
		</div>
		{#if drillSources.length > 1}
			<a
				href="/drill"
				class="mt-3 flex items-center justify-center gap-2 rounded-xl bg-primary p-4 text-sm font-bold text-white shadow-lg shadow-primary/20 transition-colors hover:bg-primary/90"
			>
				<Shuffle class="text-lg" />
				Alles gemischt &middot; {dueCount} Karten
			</a>
		{/if}
	</section>
{:else}
	<section class="mb-8">
		<div class="rounded-xl border border-primary/10 bg-white dark:bg-white/5 p-8 text-center shadow-sm">
			<p class="text-2xl font-bold text-slate-900 dark:text-slate-100">Alles erledigt!</p>
			<p class="mt-2 text-sm text-slate-500 dark:text-slate-400">Keine Karten f&auml;llig. Komm sp&auml;ter wieder.</p>
		</div>
	</section>
{/if}

<!-- Today + Lexicon — stacked on mobile, side-by-side on lg -->
<section class="mb-8 grid grid-cols-1 gap-4 lg:grid-cols-2">
	<div>
		<div class="mb-4 flex items-center justify-between">
			<h3 class="text-lg font-bold text-slate-900 dark:text-slate-100">Heute</h3>
			<a href="/stats" class="text-xs font-bold uppercase tracking-wider text-primary hover:underline">
				Alle Statistiken
			</a>
		</div>
		<div
			class="flex items-center justify-between rounded-xl border border-primary/10 bg-white p-4 dark:bg-white/5"
		>
			<div class="flex gap-2">
				{#each Array(Math.min(stats.reviewed_today, 7)) as _, i (i)}
					<div class="size-3 rounded-full bg-primary"></div>
				{/each}
				{#each Array(Math.max(0, 7 - Math.min(stats.reviewed_today, 7))) as _, i (i)}
					<div class="size-3 rounded-full bg-primary/10"></div>
				{/each}
			</div>
			<p class="text-sm text-slate-500 dark:text-slate-400">
				{stats.reviewed_today} gelernt &middot; {accuracy(stats)}
			</p>
		</div>
	</div>

	{#if stats.lexicon_count > 0}
		<div>
			<div class="mb-4 flex items-center justify-between">
				<h3 class="text-lg font-bold text-slate-900 dark:text-slate-100">Lexikon</h3>
				<a href="/lexicon" class="text-xs font-bold uppercase tracking-wider text-primary hover:underline">
					&Ouml;ffnen
				</a>
			</div>
			<a
				href="/lexicon"
				class="flex items-center justify-between rounded-xl border border-primary/10 bg-white p-4 shadow-sm transition-colors hover:bg-primary/5 dark:bg-white/5"
			>
				<div class="flex items-center gap-3">
					<Book class="text-primary" />
					<p class="text-sm text-slate-500 dark:text-slate-400">
						{stats.lexicon_count} W&ouml;rter gesammelt
					</p>
				</div>
				<ChevronRight class="text-slate-400 dark:text-slate-500" />
			</a>
		</div>
	{/if}
</section>

<!-- Recent Words -->
{#if previewCards.length > 0}
	<section class="mb-8">
		<h3 class="mb-4 text-lg font-bold text-slate-900 dark:text-slate-100">Zuletzt gelernte W&ouml;rter</h3>
		<div class="flex flex-wrap gap-2">
			{#each previewCards.slice(0, 5) as card (card.id)}
				<div
					class="rounded-full border border-primary/5 bg-white px-4 py-2 shadow-sm dark:bg-white/5"
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
