<script lang="ts">
	import Close from '$lib/icons/Close.svelte';
	import LocalFireDepartment from '$lib/icons/LocalFireDepartment.svelte';
	import { getBannerState, streakBannerStore } from '$lib/streak-banner.svelte';

	const state = $derived(getBannerState());
	const visible = $derived(!streakBannerStore.dismissed && state !== null);
</script>

{#if visible && state}
	<section
		class="mb-4 flex items-center gap-3 rounded-xl border border-amber-300/60 bg-amber-50 p-3 shadow-sm dark:border-amber-500/30 dark:bg-amber-500/10"
	>
		<div
			class="flex size-9 shrink-0 items-center justify-center rounded-lg bg-amber-400/20 dark:bg-amber-500/20"
		>
			<LocalFireDepartment class="text-amber-600 dark:text-amber-400" />
		</div>
		<div class="min-w-0 flex-1">
			<p class="text-sm font-bold text-slate-900 dark:text-slate-100">
				{state.streak}-Tage-Streak droht zu brechen
			</p>
			<p class="text-xs text-slate-600 dark:text-slate-400">
				{#if state.dueCount > 0 && state.unreadCount > 0}
					{state.dueCount} f&auml;llige &middot; {state.unreadCount} neue W&ouml;rter warten
				{:else if state.dueCount > 0}
					{state.dueCount} Karten f&auml;llig &mdash; jetzt &uuml;ben
				{:else}
					{state.unreadCount} neue W&ouml;rter zum Lesen
				{/if}
			</p>
		</div>
		<a
			href="/drill"
			class="shrink-0 rounded-lg bg-primary px-3 py-1.5 text-xs font-bold text-white shadow-sm transition-colors hover:bg-primary/90"
		>
			&Uuml;ben
		</a>
		<button
			type="button"
			onclick={() => streakBannerStore.dismiss()}
			class="shrink-0 rounded-lg p-1 text-slate-400 transition-colors hover:bg-white/50 hover:text-slate-600 dark:text-slate-500 dark:hover:bg-white/5 dark:hover:text-slate-300"
			aria-label="Banner ausblenden"
		>
			<Close class="text-[16px]" />
		</button>
	</section>
{/if}
