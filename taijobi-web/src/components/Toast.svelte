<script lang="ts">
	import { toastStore, type Toast } from '$lib/toast.svelte';

	const DURATION = 5;
	const R = 9;
	const C = 2 * Math.PI * R;
	const MAX_VISIBLE = 3;

	let hovered = $state(false);

	function onEnter() {
		hovered = true;
		toastStore.pauseAll();
	}

	function onLeave() {
		hovered = false;
		toastStore.resumeAll();
	}

	let swipeMap = new Map<string, { startX: number; deltaX: number }>();

	function onTouchStart(id: string, e: TouchEvent) {
		swipeMap.set(id, { startX: e.touches[0].clientX, deltaX: 0 });
	}

	function onTouchMove(id: string, e: TouchEvent) {
		const state = swipeMap.get(id);
		if (!state) return;
		state.deltaX = e.touches[0].clientX - state.startX;
	}

	function onTouchEnd(id: string) {
		const state = swipeMap.get(id);
		if (!state) return;
		if (Math.abs(state.deltaX) > 80) {
			toastStore.dismiss(id);
		}
		swipeMap.delete(id);
	}

	function getSwipeX(id: string): number {
		return swipeMap.get(id)?.deltaX ?? 0;
	}
</script>

{#if toastStore.toasts.length > 0}
	<!-- svelte-ignore a11y_no_static_element_interactions -->
	<div
		class="fixed bottom-24 left-1/2 z-50 w-[calc(100%-2rem)] max-w-lg -translate-x-1/2"
		onmouseenter={onEnter}
		onmouseleave={onLeave}
	>
		<div class="relative" style:height="{hovered ? toastStore.toasts.length * 64 : 56}px">
			{#each toastStore.toasts as toast, i (toast.id)}
				{@const total = toastStore.toasts.length}
				{@const idx = total - 1 - i}
				{@const isVisible = idx < MAX_VISIBLE}
				{@const scale = hovered ? 1 : 1 - idx * 0.05}
				{@const translateY = hovered ? -(idx * 60) : -(idx * 8)}
				{@const opacity = idx >= MAX_VISIBLE ? 0 : 1}
				{@const swipeX = getSwipeX(toast.id)}

				{#if isVisible || idx === MAX_VISIBLE}
					<div
						class="toast-item absolute bottom-0 left-0 right-0"
						style="
							transform: translateX({swipeX}px) translateY({translateY}px) scale({scale});
							opacity: {opacity};
							z-index: {total - idx};
							transition: {swipeX !== 0
							? 'none'
							: 'transform 0.3s cubic-bezier(0.32, 0.72, 0, 1), opacity 0.3s ease'};
						"
						ontouchstart={(e) => onTouchStart(toast.id, e)}
						ontouchmove={(e) => onTouchMove(toast.id, e)}
						ontouchend={() => onTouchEnd(toast.id)}
					>
						<div
							class="toast-bar flex items-center justify-between gap-3 rounded-2xl px-5 py-3.5 shadow-lg"
						>
							<span class="truncate text-sm font-bold">{toast.message}</span>
							<div class="flex shrink-0 items-center gap-2">
								{#if toast.onUndo}
									<button
										onclick={() => toastStore.triggerUndo(toast.id)}
										class="cursor-pointer text-sm font-bold text-accent transition-opacity hover:opacity-80"
									>
										R&uuml;ckg&auml;ngig
									</button>
								{/if}
								<button
									onclick={() => toastStore.dismiss(toast.id)}
									class="group relative flex size-7 cursor-pointer items-center justify-center"
									aria-label="Schlie&szlig;en"
								>
									{#key toast.id}
										<svg class="absolute inset-0 size-7 -rotate-90" viewBox="0 0 22 22">
											<circle
												cx="11"
												cy="11"
												r={R}
												fill="none"
												stroke="rgba(255,255,255,0.15)"
												stroke-width="2"
											/>
											<circle
												cx="11"
												cy="11"
												r={R}
												fill="none"
												class="countdown-ring"
												class:paused={toast.paused}
												stroke="rgba(255,255,255,0.5)"
												stroke-width="2"
												stroke-linecap="round"
												stroke-dasharray={C}
												stroke-dashoffset="0"
												style="--c: {C}; --d: {DURATION}s"
											/>
										</svg>
									{/key}
									<svg
										class="relative size-3 text-white/40 transition-colors group-hover:text-white"
										fill="none"
										stroke="currentColor"
										viewBox="0 0 24 24"
									>
										<path
											stroke-linecap="round"
											stroke-linejoin="round"
											stroke-width="2.5"
											d="M6 18L18 6M6 6l12 12"
										/>
									</svg>
								</button>
							</div>
						</div>
					</div>
				{/if}
			{/each}
		</div>
	</div>
{/if}

<style>
	.toast-bar {
		background-color: var(--color-slate-900, #0f172a);
		color: white;
	}
	.countdown-ring {
		animation: countdown var(--d) linear forwards;
	}
	.countdown-ring.paused {
		animation-play-state: paused;
	}
	@keyframes countdown {
		from {
			stroke-dashoffset: 0;
		}
		to {
			stroke-dashoffset: var(--c);
		}
	}
	.toast-item {
		transform-origin: center bottom;
	}
</style>
