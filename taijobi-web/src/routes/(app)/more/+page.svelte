<script lang="ts">
	import BarChart from '$lib/icons/BarChart.svelte';
	import Dictionary from '$lib/icons/Dictionary.svelte';
	import Inventory2 from '$lib/icons/Inventory2.svelte';
	import Style from '$lib/icons/Style.svelte';
	import Translate from '$lib/icons/Translate.svelte';
	import Settings from '$lib/icons/Settings.svelte';
	import type { Component } from 'svelte';

	interface MoreItem {
		href: string;
		label: string;
		desc: string;
		icon: Component;
		tint: string;
	}

	const items: MoreItem[] = [
		{
			href: '/stats',
			label: 'Statistik',
			desc: 'Streak, Reviews, Aktivität',
			icon: BarChart,
			tint: 'bg-indigo-100 text-indigo-600 dark:bg-indigo-500/15 dark:text-indigo-300'
		},
		{
			href: '/dictionary',
			label: 'Wörterbuch',
			desc: 'CEDICT, Wiktionary EN/DE',
			icon: Dictionary,
			tint: 'bg-emerald-100 text-emerald-600 dark:bg-emerald-500/15 dark:text-emerald-300'
		},
		{
			href: '/packs',
			label: 'Pakete',
			desc: 'HSK, Lóng, CSV/Anki Import',
			icon: Inventory2,
			tint: 'bg-amber-100 text-amber-600 dark:bg-amber-500/15 dark:text-amber-300'
		},
		{
			href: '/lexicon',
			label: 'Lexikon',
			desc: 'Persönliche Wortsammlung',
			icon: Style,
			tint: 'bg-rose-100 text-rose-600 dark:bg-rose-500/15 dark:text-rose-300'
		},
		{
			href: '/characters',
			label: 'Zeichen',
			desc: 'Zeichen-Übersicht & Suche',
			icon: Translate,
			tint: 'bg-sky-100 text-sky-600 dark:bg-sky-500/15 dark:text-sky-300'
		},
		{
			href: '/settings',
			label: 'Einstellungen',
			desc: 'Theme, Sync, Wörterbücher',
			icon: Settings,
			tint: 'bg-slate-100 text-slate-600 dark:bg-white/10 dark:text-slate-300'
		}
	];
</script>

<svelte:head>
	<title>Mehr — Taijobi</title>
</svelte:head>

<section class="space-y-3 py-4">
	<div class="grid grid-cols-2 gap-3">
		{#each items as item (item.href)}
			<a
				href={item.href}
				class="group flex flex-col gap-3 rounded-2xl border border-slate-100 bg-white p-4 shadow-sm transition-all hover:border-primary/30 hover:shadow-md active:scale-[0.98] dark:border-white/5 dark:bg-white/5 dark:hover:border-primary/40"
			>
				<div
					class="flex size-11 items-center justify-center rounded-xl {item.tint}"
				>
					<item.icon style="font-size: 22px" />
				</div>
				<div>
					<p class="text-sm font-bold text-slate-900 dark:text-slate-100">{item.label}</p>
					<p class="mt-0.5 text-xs leading-snug text-slate-500 dark:text-slate-400">
						{item.desc}
					</p>
				</div>
			</a>
		{/each}
	</div>

	<a
		href="/about"
		class="mt-2 flex items-center justify-between rounded-2xl border border-slate-100 bg-white p-4 shadow-sm transition-colors hover:bg-slate-50 dark:border-white/5 dark:bg-white/5 dark:hover:bg-white/10"
	>
		<div>
			<p class="text-sm font-bold text-slate-900 dark:text-slate-100">Über Taijobi</p>
			<p class="mt-0.5 text-xs text-slate-400 dark:text-slate-500">FAQ, Datenschutz, Tech Stack</p>
		</div>
		<svg class="size-4 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
			<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
		</svg>
	</a>
</section>
