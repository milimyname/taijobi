<script lang="ts">
	import { updateStore } from '$lib/update.svelte';
	import { changelogStore } from '$lib/changelog.svelte';
	import { APP_VERSION } from '$lib/version';
	import Drawer from './Drawer.svelte';

	let updating = $state(false);

	const missedReleases = $derived(changelogStore.releasesSince(APP_VERSION));

	interface ChangeItem {
		type: string;
		text: string;
	}

	const TYPE_BADGES: Record<string, { label: string; cls: string }> = {
		feat: { label: 'Feature', cls: 'bg-emerald-100 text-emerald-700' },
		fix: { label: 'Fix', cls: 'bg-rose-100 text-rose-600' },
		refactor: { label: 'Refactor', cls: 'bg-sky-100 text-sky-700' },
		perf: { label: 'Perf', cls: 'bg-amber-100 text-amber-700' }
	};

	function parseItems(body: string): ChangeItem[] {
		return body
			.split('\n')
			.map((l) => l.trim())
			.filter((l) => l.length > 0)
			.filter((l) => !l.match(/^release:\s*v[\d.]+$/i))
			.filter((l) => !l.match(/^#{1,3}\s/))
			.map((l) => l.replace(/^[-*]\s*/, '').trim())
			.filter((l) => l.length > 0)
			.map((l) => {
				const match = l.match(
					/^(feat|fix|refactor|perf|docs|style|test)(?:\(.+?\))?:\s*(.+)$/i
				);
				if (match) return { type: match[1].toLowerCase(), text: match[2].trim() };
				return { type: '', text: l };
			});
	}

	$effect(() => {
		if (updateStore.sheetOpen) changelogStore.load();
	});

	function handleUpdate() {
		updating = true;
		updateStore.activateUpdate();
	}

	function handleBreakingUpdate() {
		updating = true;
		updateStore.clearDataAndUpdate();
	}
</script>

<Drawer open={updateStore.sheetOpen} onclose={() => (updateStore.sheetOpen = false)}>
	{#snippet children({ handle, content, footer })}
		<div {@attach handle} class="flex justify-center pb-2 pt-3">
			<div class="h-1 w-10 rounded-full bg-slate-200"></div>
		</div>

		<div {@attach content} class="flex flex-col px-6">
			<div class="mb-5 flex shrink-0 items-center gap-3">
				<div
					class="flex size-11 shrink-0 items-center justify-center rounded-2xl bg-primary/10"
				>
					<span class="material-symbols-outlined text-primary">sync</span>
				</div>
				<div>
					<p class="text-base font-bold text-slate-900 dark:text-slate-100">Neue Version verf&uuml;gbar</p>
					<p class="text-sm text-slate-500 dark:text-slate-400">v{updateStore.targetVersion}</p>
				</div>
			</div>

			<div class="min-h-0 flex-1 overflow-y-auto">
				{#if changelogStore.loading && missedReleases.length === 0}
					<div class="animate-pulse space-y-2">
						<div class="h-3.5 w-full rounded bg-slate-100"></div>
						<div class="h-3.5 w-3/4 rounded bg-slate-100"></div>
					</div>
				{:else if missedReleases.length > 0}
					<div class="rounded-2xl bg-bg-light p-4">
						{#each missedReleases as release, i}
							{@const items = parseItems(release.body)}
							{#if items.length > 0}
								{#if i > 0}
									<hr class="my-3 border-slate-200 dark:border-white/10/50" />
								{/if}
								<p class="mb-2 text-xs font-bold uppercase tracking-wider text-slate-500 dark:text-slate-400">
									{release.tag}
								</p>
								<div class="space-y-1.5">
									{#each items as item}
										{@const badge = TYPE_BADGES[item.type]}
										<div class="flex items-start gap-2.5">
											{#if badge}
												<span
													class="mt-0.5 shrink-0 rounded px-1.5 py-0.5 text-[9px] font-bold {badge.cls}"
												>
													{badge.label}
												</span>
											{:else}
												<span
													class="mt-2 size-1.5 shrink-0 rounded-full bg-slate-400/30"
												></span>
											{/if}
											<p class="text-sm leading-relaxed text-slate-900 dark:text-slate-100">
												{item.text}
											</p>
										</div>
									{/each}
								</div>
							{/if}
						{/each}
					</div>
				{/if}

				{#if updateStore.hasBreaking}
					<div
						class="mt-5 rounded-xl border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-700"
					>
						Diese Version enth&auml;lt Datenbank-&Auml;nderungen. Lokale Daten m&uuml;ssen
						zur&uuml;ckgesetzt werden.
					</div>
				{/if}
			</div>
		</div>

		<div {@attach footer} class="px-6 pb-8 pt-4">
			<div class="flex gap-2.5">
				{#if updateStore.hasBreaking}
					<button
						onclick={handleBreakingUpdate}
						disabled={updating}
						class="flex-1 rounded-xl bg-amber-500 py-3 text-sm font-bold text-white transition-all active:scale-[0.98] disabled:opacity-60"
					>
						{#if updating}
							<span class="inline-flex items-center gap-2">
								<span
									class="size-4 animate-spin rounded-full border-2 border-white/40 border-t-white"
								></span>
								Aktualisiere...
							</span>
						{:else}
							Daten l&ouml;schen & aktualisieren
						{/if}
					</button>
				{:else}
					<button
						onclick={handleUpdate}
						disabled={updating}
						class="flex-1 rounded-xl bg-primary py-3 text-sm font-bold text-white transition-all active:scale-[0.98] disabled:opacity-60"
					>
						{#if updating}
							<span class="inline-flex items-center gap-2">
								<span
									class="size-4 animate-spin rounded-full border-2 border-white/40 border-t-white"
								></span>
								Aktualisiere...
							</span>
						{:else}
							Jetzt aktualisieren
						{/if}
					</button>
				{/if}
				{#if !updating}
					<button
						onclick={() => {
							updateStore.sheetOpen = false;
							updateStore.dismiss();
						}}
						class="rounded-xl px-5 py-3 text-sm font-medium text-slate-500 dark:text-slate-400 transition-colors hover:bg-slate-100 dark:hover:bg-white/10"
					>
						Sp&auml;ter
					</button>
				{/if}
			</div>
		</div>
	{/snippet}
</Drawer>
