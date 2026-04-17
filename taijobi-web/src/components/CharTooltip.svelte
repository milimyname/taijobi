<script lang="ts">
	import ChevronRight from '$lib/icons/ChevronRight.svelte';
	import { decompose, type DecompResult } from '$lib/wasm';

	let visible = $state(false);
	let x = $state(0);
	let y = $state(0);
	let selectedChar = $state('');
	let decompData: DecompResult | null = $state(null);

	function isChinese(char: string): boolean {
		const code = char.codePointAt(0) ?? 0;
		return (
			(code >= 0x4e00 && code <= 0x9fff) ||
			(code >= 0x3400 && code <= 0x4dbf) ||
			(code >= 0x20000 && code <= 0x2a6df)
		);
	}

	function handleSelectionChange() {
		const sel = window.getSelection();
		if (!sel || sel.isCollapsed || !sel.toString().trim()) {
			visible = false;
			return;
		}

		const text = sel.toString().trim();

		// Find the first Chinese character in the selection
		let found = '';
		for (const ch of text) {
			if (isChinese(ch)) {
				found = ch;
				break;
			}
		}

		if (!found) {
			visible = false;
			return;
		}

		// Get position from selection range
		const range = sel.getRangeAt(0);
		const rect = range.getBoundingClientRect();

		selectedChar = found;
		decompData = decompose(found);
		x = rect.left + rect.width / 2;
		y = rect.top - 8;
		visible = true;
	}

	function hide() {
		visible = false;
	}
</script>

<svelte:document
	onselectionchange={handleSelectionChange}
	onpointerdown={(e) => {
		// Hide if clicking outside the tooltip
		const target = e.target as HTMLElement;
		if (!target.closest('.char-tooltip')) {
			// Delay to let selection happen first
			setTimeout(() => {
				if (!window.getSelection()?.toString().trim()) {
					visible = false;
				}
			}, 100);
		}
	}}
/>

{#if visible && selectedChar}
	<div
		class="char-tooltip fixed z-50 -translate-x-1/2 -translate-y-full"
		style="left: {x}px; top: {y}px;"
	>
		<a
			href="/character/{encodeURIComponent(selectedChar)}"
			onclick={hide}
			class="flex items-center gap-2.5 rounded-xl border border-slate-200 dark:border-white/10 bg-white dark:bg-slate-800 px-3 py-2 shadow-lg transition-colors hover:bg-slate-50 dark:hover:bg-slate-700"
		>
			<span class="chinese-char text-2xl text-primary">{selectedChar}</span>
			<div class="text-left">
				{#if decompData}
					<p class="text-xs font-medium text-primary">{decompData.pinyin}</p>
					<p class="max-w-[160px] truncate text-[11px] text-slate-500 dark:text-slate-400">{decompData.definition}</p>
				{:else}
					<p class="text-xs text-slate-400 dark:text-slate-500">Details anzeigen</p>
				{/if}
			</div>
			<ChevronRight class="text-[16px] text-slate-300 dark:text-slate-500" />
		</a>
		<!-- Arrow -->
		<div
			class="absolute left-1/2 top-full -translate-x-1/2 border-[6px] border-transparent border-t-white dark:border-t-slate-800"
		></div>
	</div>
{/if}
