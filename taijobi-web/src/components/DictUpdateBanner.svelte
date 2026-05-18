<script lang="ts">
	import Close from '$lib/icons/Close.svelte';
	import Sync from '$lib/icons/Sync.svelte';
	import { dictUpdateStore } from '$lib/dict-update.svelte';

	const visible = $derived(!dictUpdateStore.dismissed && dictUpdateStore.staleKinds.length > 0);

	const sizeLabel = $derived.by(() => {
		const kinds = dictUpdateStore.staleKinds;
		if (kinds.length === 2) return '~25 MB';
		if (kinds.includes('en')) return '~19 MB';
		return '~5 MB';
	});

	const langLabel = $derived.by(() => {
		const kinds = dictUpdateStore.staleKinds;
		if (kinds.length === 2) return 'Englisch &amp; Deutsch';
		return kinds.includes('en') ? 'Englisch' : 'Deutsch';
	});
</script>

{#if visible}
	<section
		class="mb-4 flex items-center gap-3 rounded-xl border border-primary/30 bg-primary/5 p-3 shadow-sm dark:border-primary/40 dark:bg-primary/10"
	>
		<div
			class="flex size-9 shrink-0 items-center justify-center rounded-lg bg-primary/15 dark:bg-primary/25"
		>
			<Sync class="text-primary dark:text-accent" />
		</div>
		<div class="min-w-0 flex-1">
			<p class="text-sm font-bold text-slate-900 dark:text-slate-100">
				W&ouml;rterbuch-Update verf&uuml;gbar
			</p>
			<p class="text-xs text-slate-600 dark:text-slate-400">
				{@html langLabel} neu laden ({sizeLabel})
			</p>
		</div>
		<button
			type="button"
			onclick={() => dictUpdateStore.refresh()}
			disabled={dictUpdateStore.busy}
			class="shrink-0 rounded-lg bg-primary px-3 py-1.5 text-xs font-bold text-white shadow-sm transition-colors hover:bg-primary/90 disabled:cursor-not-allowed disabled:opacity-60"
		>
			{dictUpdateStore.busy ? 'L&auml;dt&hellip;' : 'Aktualisieren'}
		</button>
		<button
			type="button"
			onclick={() => dictUpdateStore.dismiss()}
			class="shrink-0 rounded-lg p-1 text-slate-400 transition-colors hover:bg-white/50 hover:text-slate-600 dark:text-slate-500 dark:hover:bg-white/5 dark:hover:text-slate-300"
			aria-label="Banner ausblenden"
		>
			<Close class="text-[16px]" />
		</button>
	</section>
{/if}
