<script lang="ts">
	import { getPacks, installPack, removePack, type Pack } from '$lib/wasm';
	import { onMount } from 'svelte';

	interface CatalogEntry {
		id: string;
		name: string;
		language_pair: string;
		word_count: number;
		description: string;
	}

	let installed: Pack[] = $state([]);
	let catalog: CatalogEntry[] = $state([]);
	let loading = $state('');
	let errorMsg = $state('');

	function refresh() {
		installed = getPacks();
	}

	onMount(async () => {
		refresh();
		try {
			const res = await fetch('/packs/catalog.json');
			catalog = await res.json();
		} catch {
			console.error('Failed to load pack catalog');
		}
	});

	let available = $derived(
		catalog.filter((c) => !installed.some((p) => p.id === c.id))
	);

	function isInstalled(id: string): boolean {
		return installed.some((p) => p.id === id);
	}

	async function handleInstall(id: string) {
		loading = id;
		errorMsg = '';
		try {
			const res = await fetch(`/packs/${id}.json`);
			const json = await res.text();
			await installPack(json);
			refresh();
		} catch (e) {
			errorMsg = e instanceof Error ? e.message : 'Install failed';
			setTimeout(() => (errorMsg = ''), 3000);
		} finally {
			loading = '';
		}
	}

	async function handleRemove(id: string) {
		try {
			await removePack(id);
			refresh();
		} catch (e) {
			errorMsg = e instanceof Error ? e.message : 'Remove failed';
			setTimeout(() => (errorMsg = ''), 3000);
		}
	}
</script>

{#if errorMsg}
	<div class="mt-4 rounded-xl border border-red-200 bg-red-50 px-4 py-2.5 text-sm text-red-700">
		{errorMsg}
	</div>
{/if}

<!-- Installed Packs -->
{#if installed.length > 0}
	<section class="mt-6">
		<h2 class="mb-4 flex items-center gap-2 text-lg font-bold text-slate-900">
			<span class="material-symbols-outlined text-primary">download_done</span>
			Installiert
		</h2>
		<div class="space-y-4">
			{#each installed as pack (pack.id)}
				<div
					class="rounded-2xl border border-slate-100 bg-white p-4 shadow-sm"
				>
					<div class="mb-3 flex items-start gap-4">
						<div
							class="flex size-16 shrink-0 items-center justify-center rounded-lg bg-primary/10"
						>
							<span class="material-symbols-outlined text-3xl text-primary">language</span>
						</div>
						<div class="min-w-0 flex-1">
							<h3 class="truncate text-lg font-bold">{pack.name}</h3>
							<p class="text-sm text-slate-500">
								{pack.language_pair} &bull; {pack.word_count} W&ouml;rter
							</p>
						</div>
					</div>
					<div class="flex justify-between">
						<a
							href="/lessons/{pack.id}"
							class="text-sm font-medium text-primary"
						>
							Lektionen anzeigen &rarr;
						</a>
						<button
							onclick={() => handleRemove(pack.id)}
							class="flex items-center gap-1 rounded-lg px-3 py-1.5 text-sm font-medium text-red-600 transition-colors hover:bg-red-50"
						>
							<span class="material-symbols-outlined text-sm">delete</span>
							Entfernen
						</button>
					</div>
				</div>
			{/each}
		</div>
	</section>
{/if}

<!-- Available Packs -->
{#if available.length > 0}
	<section class="mt-8">
		<h2 class="mb-4 flex items-center gap-2 text-lg font-bold text-slate-900">
			<span class="material-symbols-outlined text-primary">explore</span>
			Verf&uuml;gbar
		</h2>
		<div class="space-y-4">
			{#each available as entry (entry.id)}
				<div
					class="rounded-2xl border border-slate-100 bg-white p-4 shadow-sm"
				>
					<div class="mb-3 flex items-start gap-4">
						<div
							class="flex size-16 shrink-0 items-center justify-center rounded-lg bg-primary/5"
						>
							<span class="material-symbols-outlined text-3xl text-primary">inventory_2</span>
						</div>
						<div class="min-w-0 flex-1">
							<h3 class="truncate text-lg font-bold">{entry.name}</h3>
							<p class="text-sm text-slate-500">{entry.description}</p>
							<p class="text-xs text-slate-400">{entry.word_count} W&ouml;rter</p>
						</div>
					</div>
					<button
						onclick={() => handleInstall(entry.id)}
						disabled={loading === entry.id}
						class="flex w-full items-center justify-center gap-2 rounded-xl bg-primary py-2.5 font-medium text-white transition-colors hover:bg-primary/90 disabled:opacity-50"
					>
						{#if loading === entry.id}
							Installiere...
						{:else}
							<span class="material-symbols-outlined text-sm">download</span>
							Installieren
						{/if}
					</button>
				</div>
			{/each}
		</div>
	</section>
{/if}

{#if installed.length === 0 && available.length === 0}
	<div class="mt-8 rounded-2xl border border-slate-100 bg-white p-8 text-center shadow-sm">
		<span class="material-symbols-outlined mb-2 text-[32px] text-slate-300">inventory_2</span>
		<p class="text-sm text-slate-500">Lade Pakete...</p>
	</div>
{/if}
