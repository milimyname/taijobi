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
		if (kinds.length === 2) return 'Englisch + Deutsch';
		return kinds.includes('en') ? 'Englisch' : 'Deutsch';
	});
</script>

{#if visible}
	<div class="flex w-full items-center bg-primary text-sm font-medium text-white">
		<button
			type="button"
			onclick={() => dictUpdateStore.refresh()}
			disabled={dictUpdateStore.busy}
			class="flex flex-1 items-center justify-center gap-2 px-4 py-2 disabled:opacity-80"
		>
			<Sync class="text-[16px] {dictUpdateStore.busy ? 'animate-spin' : ''}" />
			{#if dictUpdateStore.busy}
				W&ouml;rterbuch wird aktualisiert&hellip;
			{:else if dictUpdateStore.error}
				Fehler: {dictUpdateStore.error}
			{:else}
				W&ouml;rterbuch-Update ({langLabel}, {sizeLabel}) &mdash; tippen zum Aktualisieren
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
