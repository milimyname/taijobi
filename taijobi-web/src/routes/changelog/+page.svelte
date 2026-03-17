<script lang="ts">
	import { onMount } from 'svelte';
	import { changelogStore } from '$lib/changelog.svelte';
	import { APP_VERSION } from '$lib/version';
	import { RELEASES_URL } from '$lib/config';

	onMount(() => {
		changelogStore.load();
	});

	function formatDate(iso: string): string {
		return new Date(iso).toLocaleDateString('de-DE', {
			day: 'numeric',
			month: 'short',
			year: 'numeric'
		});
	}

	interface ChangeItem {
		type: string;
		text: string;
	}

	const TYPE_BADGES: Record<string, { label: string; cls: string }> = {
		feat: { label: 'Feature', cls: 'bg-emerald-100 text-emerald-700' },
		fix: { label: 'Fix', cls: 'bg-rose-100 text-rose-600' },
		refactor: { label: 'Refactor', cls: 'bg-sky-100 text-sky-700' },
		perf: { label: 'Perf', cls: 'bg-amber-100 text-amber-700' },
		docs: { label: 'Docs', cls: 'bg-slate-100 text-slate-600' },
		style: { label: 'Style', cls: 'bg-purple-100 text-purple-600' },
		test: { label: 'Test', cls: 'bg-indigo-100 text-indigo-600' }
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
</script>

<div class="mx-auto flex max-w-lg flex-col gap-8 px-6 py-12">
	<!-- Header -->
	<header class="space-y-2">
		<div class="flex items-center justify-between">
			<h1 class="text-3xl font-extrabold tracking-tight text-slate-900">Was ist neu?</h1>
			<a href="/" class="text-sm font-bold text-slate-500 transition-colors hover:text-slate-900">
				Zur App &rarr;
			</a>
		</div>
		<p class="text-lg text-slate-500">Die neuesten Updates f&uuml;r Taijobi</p>
	</header>

	{#if changelogStore.loading && changelogStore.releases.length === 0}
		<div class="flex flex-col gap-4">
			{#each { length: 3 } as _}
				<div class="animate-pulse rounded-2xl border border-slate-100 bg-white p-6 shadow-sm">
					<div class="mb-4 flex items-center justify-between">
						<div class="h-6 w-16 rounded-full bg-slate-200"></div>
						<div class="h-4 w-20 rounded bg-slate-100"></div>
					</div>
					<div class="space-y-3">
						<div class="h-4 w-full rounded bg-slate-100"></div>
						<div class="h-4 w-4/5 rounded bg-slate-100"></div>
					</div>
				</div>
			{/each}
		</div>
	{:else if changelogStore.releases.length > 0}
		<section class="flex flex-col gap-4">
			{#each changelogStore.releases as release, i}
				{@const isCurrent = release.tag === `v${APP_VERSION}`}
				{@const items = parseItems(release.body)}

				<article
					class="flex flex-col gap-4 rounded-2xl border border-slate-100 bg-white p-6 shadow-sm {i > 4 ? 'opacity-70' : ''}"
				>
					<div class="flex items-center justify-between">
						<div class="flex items-center gap-2">
							<span
								class="rounded-full px-3 py-1 text-xs font-bold {isCurrent
									? 'bg-primary/10 text-primary'
									: 'bg-slate-100 text-slate-500'}"
							>
								{release.tag}
							</span>
							{#if isCurrent}
								<span class="size-2 animate-pulse rounded-full bg-primary"></span>
							{/if}
						</div>
						<time class="text-sm text-slate-500">{formatDate(release.date)}</time>
					</div>

					{#if items.length > 0}
						<div class="grid grid-cols-[auto_1fr] items-baseline gap-x-3 gap-y-2">
							{#each items as item}
								{@const badge = TYPE_BADGES[item.type]}
								{#if badge}
									<span
										class="min-w-[4rem] rounded-md px-2 py-0.5 text-center text-[10px] font-bold {badge.cls}"
									>
										{badge.label}
									</span>
								{:else}
									<span class="flex min-w-[4rem] items-center justify-center">
										<span class="size-1.5 rounded-full bg-slate-400/30"></span>
									</span>
								{/if}
								<p class="text-sm font-medium leading-relaxed text-slate-900">
									{item.text}
								</p>
							{/each}
						</div>
					{:else}
						<p class="text-sm italic text-slate-500">Wartungsrelease.</p>
					{/if}
				</article>
			{/each}
		</section>

		<footer class="mt-4 flex flex-col items-center gap-4">
			<a
				href="/"
				class="w-full rounded-2xl bg-primary py-4 text-center font-extrabold text-white shadow-sm transition-colors hover:bg-primary/90"
			>
				Verstanden!
			</a>
			<a
				href={RELEASES_URL}
				target="_blank"
				rel="noopener noreferrer"
				class="text-xs text-slate-500 hover:underline"
			>
				Alle Releases auf GitHub ansehen
			</a>
		</footer>
	{:else if changelogStore.error}
		<div class="rounded-2xl border border-slate-100 bg-white p-6 text-center shadow-sm">
			<p class="mb-3 text-sm text-slate-500">Changelog konnte nicht geladen werden.</p>
			<a
				href={RELEASES_URL}
				target="_blank"
				rel="noopener noreferrer"
				class="inline-flex items-center gap-1.5 text-sm font-medium text-primary hover:underline"
			>
				Auf GitHub ansehen
			</a>
		</div>
	{/if}
</div>
