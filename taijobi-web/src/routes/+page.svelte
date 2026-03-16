<script lang="ts">
	import { getDueCount, getDueCards, type Card } from '$lib/wasm';

	let dueCount = $derived(getDueCount());
	let previewCards: Card[] = $derived(getDueCards(3));
</script>

<!-- Hero Card -->
<section class="mt-4">
	{#if dueCount > 0}
		<div
			class="relative overflow-hidden rounded-xl border border-border-subtle bg-white p-6 shadow-sm"
		>
			<div class="mb-8 flex items-start justify-between">
				<div>
					<span class="text-[11px] font-bold uppercase tracking-widest text-primary"
						>Ready to Review</span
					>
					<h1 class="mt-1 text-2xl font-bold text-stone-900">{dueCount} Cards Due</h1>
					<p class="mt-1 text-sm text-stone-500">
						L&oacute;ng neu L5 vocabulary
					</p>
				</div>
				<div class="chinese-char select-none text-5xl font-bold text-primary opacity-10">
					课练
				</div>
			</div>
			<a
				href="/drill"
				class="flex w-full items-center justify-center gap-2 rounded-lg bg-primary py-3.5 font-semibold text-white shadow-md shadow-primary/20 transition-all hover:bg-primary/90 active:scale-[0.98]"
			>
				<span>Start Review</span>
				<span class="material-symbols-outlined text-[18px]">arrow_forward</span>
			</a>
		</div>
	{:else}
		<div
			class="rounded-xl border border-border-subtle bg-white p-8 text-center shadow-sm"
		>
			<p class="text-2xl font-bold text-stone-900">All caught up!</p>
			<p class="mt-2 text-sm text-stone-500">No cards due right now. Come back later.</p>
		</div>
	{/if}
</section>

<!-- Review Queue Preview -->
{#if previewCards.length > 0}
	<section class="mt-10">
		<div class="mb-4 flex items-center justify-between">
			<h3 class="text-[11px] font-bold uppercase tracking-[0.2em] text-stone-400">Queue</h3>
			<a href="/drill" class="text-[11px] font-bold uppercase tracking-wider text-primary"
				>Review All</a
			>
		</div>
		<div class="space-y-3">
			{#each previewCards as card}
				<div
					class="flex items-center rounded-xl border border-border-subtle bg-white p-4 shadow-sm"
				>
					<div
						class="chinese-char mr-4 flex size-12 items-center justify-center rounded-lg bg-surface text-2xl font-medium text-stone-800"
					>
						{card.word}
					</div>
					<div class="flex-1">
						<div class="text-sm font-semibold text-stone-900">
							{card.translation ?? '—'}
						</div>
						<div class="text-[11px] font-medium uppercase tracking-tight text-stone-400">
							{card.pinyin ?? ''} {card.reps === 0 ? '• New' : '• Due'}
						</div>
					</div>
					<span class="material-symbols-outlined text-[20px] text-stone-300">chevron_right</span>
				</div>
			{/each}
		</div>
	</section>
{/if}
