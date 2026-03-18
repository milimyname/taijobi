<script lang="ts">
	import {
		getWasmMemoryBytes,
		getWasmDbSize,
		getBuildId,
		getPacks,
		getDrillStats,
		close,
		type Pack
	} from '$lib/wasm';

	let open = $state(false);
	let memoryBytes = $state(0);
	let dbSizeBytes = $state(0);
	let buildId = $state('');
	let packs: Pack[] = $state([]);
	let cardCount = $state(0);
	let lexiconCount = $state(0);
	let confirmReset = $state(false);

	function refresh() {
		memoryBytes = getWasmMemoryBytes();
		dbSizeBytes = getWasmDbSize();
		buildId = getBuildId();
		packs = getPacks();
		const stats = getDrillStats();
		cardCount = stats.total_cards;
		lexiconCount = stats.lexicon_count;
	}

	function toggle() {
		open = !open;
		if (open) refresh();
	}

	function formatBytes(bytes: number): string {
		if (bytes < 1024) return `${bytes} B`;
		if (bytes < 1048576) return `${(bytes / 1024).toFixed(1)} KB`;
		return `${(bytes / 1048576).toFixed(1)} MB`;
	}

	async function clearOpfs() {
		try {
			close();
			const root = await navigator.storage.getDirectory();
			await root.removeEntry('taijobi.db');
		} catch {
			/* ignore */
		}
		window.location.reload();
	}

	async function fullReset() {
		try {
			close();
			const root = await navigator.storage.getDirectory();
			await root.removeEntry('taijobi.db');
		} catch {
			/* ignore */
		}
		localStorage.clear();
		window.location.reload();
	}
</script>

<!-- Toggle button (bottom-left, above nav) -->
<button
	onclick={toggle}
	class="fixed bottom-20 left-3 z-50 flex size-8 items-center justify-center rounded-full bg-slate-800 text-xs font-bold text-white opacity-30 transition-opacity hover:opacity-100"
	aria-label="DevTools"
>
	{open ? 'x' : 'D'}
</button>

{#if open}
	<div
		class="fixed bottom-28 left-3 z-50 w-72 overflow-hidden rounded-2xl border border-slate-200 bg-white shadow-lg"
	>
		<!-- Header -->
		<div class="flex items-center justify-between border-b border-slate-100 px-4 py-2.5">
			<span class="text-xs font-bold tracking-wide text-slate-900">DevTools</span>
			<button
				onclick={() => {
					open = false;
				}}
				class="cursor-pointer text-xs text-slate-400 hover:text-slate-700"
			>
				close
			</button>
		</div>

		<div class="max-h-80 space-y-3 overflow-y-auto p-3">
			<!-- Build -->
			<div class="rounded-lg bg-slate-50 px-3 py-2">
				<div class="text-[9px] font-bold uppercase tracking-wider text-slate-400">Build</div>
				<div class="mt-0.5 font-mono text-xs text-slate-700">{buildId}</div>
			</div>

			<!-- Memory -->
			<div class="grid grid-cols-2 gap-2">
				<div class="rounded-lg bg-slate-50 px-3 py-2 text-center">
					<div class="text-sm font-bold text-slate-900">{formatBytes(memoryBytes)}</div>
					<div class="text-[9px] text-slate-400">WASM Memory</div>
				</div>
				<div class="rounded-lg bg-slate-50 px-3 py-2 text-center">
					<div class="text-sm font-bold text-slate-900">{formatBytes(dbSizeBytes)}</div>
					<div class="text-[9px] text-slate-400">SQLite DB</div>
				</div>
			</div>

			<!-- Data -->
			<div class="grid grid-cols-2 gap-2">
				<div class="rounded-lg bg-slate-50 px-3 py-2 text-center">
					<div class="text-sm font-bold text-slate-900">{cardCount}</div>
					<div class="text-[9px] text-slate-400">Karten</div>
				</div>
				<div class="rounded-lg bg-slate-50 px-3 py-2 text-center">
					<div class="text-sm font-bold text-slate-900">{lexiconCount}</div>
					<div class="text-[9px] text-slate-400">Lexikon</div>
				</div>
			</div>

			<!-- Packs -->
			{#if packs.length > 0}
				<div>
					<div class="mb-1 text-[9px] font-bold uppercase tracking-wider text-slate-400">
						Packs ({packs.length})
					</div>
					{#each packs as pack}
						<div class="flex items-center justify-between py-0.5 text-xs">
							<span class="truncate text-slate-700">{pack.name}</span>
							<span class="shrink-0 text-slate-400">{pack.word_count}</span>
						</div>
					{/each}
				</div>
			{/if}

			<!-- OPFS -->
			<div>
				<button
					onclick={async () => {
						try {
							const root = await navigator.storage.getDirectory();
							const entries: string[] = [];
							for await (const [name] of (root as any).entries()) entries.push(name);
							alert('OPFS: ' + (entries.length ? entries.join(', ') : 'empty'));
						} catch {
							alert('OPFS not available');
						}
					}}
					class="w-full cursor-pointer rounded-lg bg-slate-50 px-3 py-1.5 text-left text-[10px] font-medium text-slate-600 hover:bg-slate-100"
				>
					Browse OPFS
				</button>
			</div>

			<!-- Actions -->
			<button
				onclick={refresh}
				class="w-full cursor-pointer rounded-lg bg-primary/10 px-3 py-1.5 text-center text-[10px] font-bold text-primary hover:bg-primary/20"
			>
				Refresh
			</button>

			<!-- Danger Zone -->
			<div class="border-t border-red-100 pt-2">
				<div class="mb-1 text-[9px] font-bold uppercase tracking-wider text-red-400">
					Danger Zone
				</div>
				{#if confirmReset}
					<div class="rounded-lg bg-red-50 p-2.5">
						<p class="mb-2 text-[10px] font-medium text-red-700">
							Alles l&ouml;schen? (OPFS + localStorage)
						</p>
						<div class="flex gap-2">
							<button
								onclick={fullReset}
								class="cursor-pointer rounded-lg bg-red-500 px-3 py-1 text-[10px] font-bold text-white hover:bg-red-600"
							>
								Ja, l&ouml;schen
							</button>
							<button
								onclick={() => {
									confirmReset = false;
								}}
								class="cursor-pointer text-[10px] text-slate-500 hover:text-slate-700"
							>
								Abbrechen
							</button>
						</div>
					</div>
				{:else}
					<button
						onclick={() => clearOpfs()}
						class="w-full cursor-pointer rounded-lg px-3 py-1.5 text-left text-[10px] font-medium text-red-600 hover:bg-red-50"
					>
						Clear OPFS (taijobi.db)
					</button>
					<button
						onclick={() => {
							confirmReset = true;
						}}
						class="w-full cursor-pointer rounded-lg px-3 py-1.5 text-left text-[10px] font-medium text-red-600 hover:bg-red-50"
					>
						Full Reset
					</button>
				{/if}
			</div>
		</div>
	</div>
{/if}
