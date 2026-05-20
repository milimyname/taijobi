<script lang="ts">
	import Close from '$lib/icons/Close.svelte';
	import Download from '$lib/icons/Download.svelte';
	import Sync from '$lib/icons/Sync.svelte';
	import { dictUpdateStore } from '$lib/dict-update.svelte';
	import { downloadStore } from '$lib/download-state.svelte';
	import Drawer from './Drawer.svelte';

	const visible = $derived(!dictUpdateStore.dismissed && dictUpdateStore.affectedKinds.length > 0);

	// Approximate served sizes per kind in MB. Match catalog.json values.
	// Used here (not pulled from catalog) because the catalog fetch is async
	// and we want zero network on the boot path that triggers this banner.
	const SIZE_MB: Record<'zh' | 'en' | 'de', number> = { zh: 19, en: 141, de: 11 };

	const LABELS: Record<'zh' | 'en' | 'de', string> = {
		zh: 'Chinesisch',
		en: 'Englisch',
		de: 'Deutsch'
	};

	const totalMb = $derived(
		dictUpdateStore.affectedKinds.reduce((sum, k) => sum + SIZE_MB[k], 0)
	);

	const langLabel = $derived(
		dictUpdateStore.affectedKinds.map((k) => LABELS[k]).join(' + ')
	);

	// Show a Wi-Fi nudge above 30 MB. Below that, even a 4G refill is harmless
	// and the extra friction would be patronising.
	const largeDownload = $derived(totalMb >= 30);

	const progressPct = $derived(
		downloadStore.total > 0
			? Math.min(100, Math.round((downloadStore.progress / downloadStore.total) * 100))
			: 0
	);

	const progressMb = $derived(downloadStore.progress / 1024 / 1024);
	const totalDownloadMb = $derived(downloadStore.total / 1024 / 1024);
</script>

{#if visible}
	<div class="flex w-full items-center bg-primary text-sm font-medium text-white">
		<button
			type="button"
			onclick={() => dictUpdateStore.open()}
			class="flex flex-1 items-center justify-center gap-2 px-4 py-2"
		>
			<Sync class="text-[16px] {dictUpdateStore.busy ? 'animate-spin' : ''}" />
			{#if dictUpdateStore.busy}
				Wörterbuch wird aktualisiert… {progressPct}%
			{:else if dictUpdateStore.error}
				Fehler — antippen zum Erneut versuchen
			{:else}
				Wörterbuch neu laden ({langLabel}, ~{totalMb} MB) — antippen für Details
			{/if}
		</button>
		{#if !dictUpdateStore.busy}
			<button
				type="button"
				onclick={() => dictUpdateStore.dismiss()}
				aria-label="Banner ausblenden"
				class="shrink-0 px-3 py-2 text-white/80 transition-colors hover:bg-black/10 hover:text-white"
			>
				<Close class="text-[16px]" />
			</button>
		{/if}
	</div>
{/if}

<Drawer open={dictUpdateStore.sheetOpen} onclose={() => dictUpdateStore.close()}>
	{#snippet children({ handle, content, footer })}
		<div {@attach handle} class="flex justify-center pb-2 pt-3">
			<div class="h-1 w-10 rounded-full bg-slate-200 dark:bg-white/20"></div>
		</div>

		<div {@attach content} class="flex flex-col px-6">
			<div class="mb-5 flex shrink-0 items-center gap-3">
				<div class="flex size-11 shrink-0 items-center justify-center rounded-2xl bg-primary/10">
					<Download class="text-primary" />
				</div>
				<div class="min-w-0">
					<p class="text-base font-bold text-slate-900 dark:text-slate-100">Wörterbuch neu laden</p>
					<p class="text-sm text-slate-500 dark:text-slate-400">{langLabel} · ~{totalMb} MB</p>
				</div>
			</div>

			<div class="min-h-0 flex-1 space-y-3 overflow-y-auto">
				<div class="rounded-2xl bg-slate-50 p-4 dark:bg-white/5">
					<p class="text-sm leading-relaxed text-slate-700 dark:text-slate-200">
						Eine oder mehrere Wörterbücher fehlen oder sind im alten Format.
						Beim Antippen werden sie neu heruntergeladen und ersetzen die alten
						Daten lokal — deine Lexikon- und Übungsdaten bleiben unberührt.
					</p>
					<ul class="mt-3 space-y-1.5">
						{#each dictUpdateStore.affectedKinds as kind (kind)}
							<li class="flex items-center justify-between text-sm">
								<span class="font-medium text-slate-700 dark:text-slate-200">{LABELS[kind]}</span>
								<span class="text-xs text-slate-400 dark:text-slate-500">~{SIZE_MB[kind]} MB</span>
							</li>
						{/each}
					</ul>
				</div>

				{#if largeDownload}
					<div
						class="rounded-2xl border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-700 dark:border-amber-500/30 dark:bg-amber-500/10 dark:text-amber-300"
					>
						<p class="font-bold">Großer Download</p>
						<p class="mt-1 leading-relaxed">
							Verbinde dich mit WLAN, bevor du startest — im Mobilfunknetz kann
							das Datenvolumen verbrauchen. Lass die App offen, bis der Download
							fertig ist; auf iOS kann sie sonst im Hintergrund beendet werden.
						</p>
					</div>
				{/if}

				{#if dictUpdateStore.busy}
					<div class="rounded-2xl border border-primary/20 bg-primary/5 px-4 py-3 dark:border-primary/30 dark:bg-primary/10">
						<div class="flex items-center justify-between text-sm">
							<span class="font-medium text-primary dark:text-accent">{progressPct}%</span>
							<span class="text-xs text-slate-500 dark:text-slate-400">
								{progressMb.toFixed(1)} / {totalDownloadMb.toFixed(1)} MB
							</span>
						</div>
						<div class="mt-2 h-1.5 w-full overflow-hidden rounded-full bg-slate-100 dark:bg-white/10">
							<div
								class="h-full rounded-full bg-primary transition-[width] duration-200 dark:bg-accent"
								style="width: {progressPct}%"
							></div>
						</div>
					</div>
				{/if}

				{#if dictUpdateStore.error}
					<div
						class="rounded-2xl border border-rose-200 bg-rose-50 px-4 py-3 text-sm text-rose-700 dark:border-rose-500/30 dark:bg-rose-500/10 dark:text-rose-300"
					>
						<p class="font-bold">Download fehlgeschlagen</p>
						<p class="mt-1 break-words leading-relaxed">{dictUpdateStore.error}</p>
					</div>
				{/if}
			</div>
		</div>

		<div {@attach footer} class="px-6 pb-8 pt-4">
			<div class="flex gap-2.5">
				<button
					onclick={() => dictUpdateStore.refresh()}
					disabled={dictUpdateStore.busy}
					class="flex-1 rounded-xl bg-primary py-3 text-sm font-bold text-white transition-all active:scale-[0.98] disabled:opacity-60"
				>
					{#if dictUpdateStore.busy}
						<span class="inline-flex items-center gap-2">
							<span class="size-4 animate-spin rounded-full border-2 border-white/40 border-t-white"></span>
							Lädt … {progressPct}%
						</span>
					{:else if dictUpdateStore.error}
						Erneut versuchen
					{:else}
						Jetzt herunterladen
					{/if}
				</button>
				{#if !dictUpdateStore.busy}
					<button
						onclick={() => dictUpdateStore.close()}
						class="rounded-xl px-5 py-3 text-sm font-medium text-slate-500 transition-colors hover:bg-slate-100 dark:text-slate-400 dark:hover:bg-white/10"
					>
						Später
					</button>
				{/if}
			</div>
		</div>
	{/snippet}
</Drawer>
