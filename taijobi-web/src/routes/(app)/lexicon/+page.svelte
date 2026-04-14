<script lang="ts">
	import Add from '$lib/icons/Add.svelte';
	import Book2 from '$lib/icons/Book2.svelte';
	import Check from '$lib/icons/Check.svelte';
	import Close from '$lib/icons/Close.svelte';
	import Delete from '$lib/icons/Delete.svelte';
	import Edit from '$lib/icons/Edit.svelte';
	import Mic from '$lib/icons/Mic.svelte';
	import PhotoCamera from '$lib/icons/PhotoCamera.svelte';
	import UploadFile from '$lib/icons/UploadFile.svelte';
	import { addWord, removeWord, updateWord, type LexiconEntry, type AddWordResult } from '$lib/wasm';
	import { data } from '$lib/data.svelte';

	let input = $state('');
	let feedback: AddWordResult | null = $state(null);
	let errorMsg = $state('');
	let adding = $state(false);
	let filter = $state('all');
	let editingId = $state<string | null>(null);
	let editTranslation = $state('');

	let entries: LexiconEntry[] = $derived(data.lexicon());

	let filtered = $derived(
		filter === 'all' ? entries : entries.filter((e) => e.language === filter),
	);

	async function handleAdd() {
		const word = input.trim();
		if (!word || adding) return;
		adding = true;
		errorMsg = '';
		feedback = null;
		try {
			const result = await addWord(word);
			feedback = result;
			input = '';
	
			setTimeout(() => (feedback = null), 3000);
		} catch (e) {
			errorMsg = e instanceof Error ? e.message : 'Failed to add word';
			setTimeout(() => (errorMsg = ''), 3000);
		} finally {
			adding = false;
		}
	}

	function handleKeydown(e: KeyboardEvent) {
		if (e.key === 'Enter') handleAdd();
	}

	async function handleRemove(id: string) {
		try {
			await removeWord(id);
	
		} catch (e) {
			errorMsg = e instanceof Error ? e.message : 'Failed to remove';
			setTimeout(() => (errorMsg = ''), 3000);
		}
	}

	function startEdit(entry: LexiconEntry) {
		editingId = entry.id;
		editTranslation = entry.translation ?? '';
	}

	function cancelEdit() {
		editingId = null;
		editTranslation = '';
	}

	async function saveEdit() {
		if (!editingId) return;
		try {
			await updateWord(editingId, editTranslation);
			editingId = null;
			editTranslation = '';
	
		} catch (e) {
			errorMsg = e instanceof Error ? e.message : 'Failed to update';
			setTimeout(() => (errorMsg = ''), 3000);
		}
	}

	function handleEditKeydown(e: KeyboardEvent) {
		if (e.key === 'Enter') saveEdit();
		if (e.key === 'Escape') cancelEdit();
	}

	function langTag(code: string): string {
		switch (code) {
			case 'zh':
				return 'ZH';
			case 'de':
				return 'DE';
			case 'en':
				return 'EN';
			default:
				return code.toUpperCase();
		}
	}

	function statusColor(entry: LexiconEntry): string {
		if (entry.reps === 0) return 'bg-slate-300';
		if (entry.stability > 5) return 'bg-[#2d6a4f]';
		return 'bg-amber-500';
	}

	function statusTitle(entry: LexiconEntry): string {
		if (entry.reps === 0) return 'Neu';
		if (entry.stability > 5) return 'Gelernt';
		return 'Wiederholen';
	}
</script>

<!-- Import from Kindle link -->
<section class="mt-4">
	<a
		href="/lexicon/import"
		class="flex items-center justify-between rounded-xl border border-primary/10 bg-primary/5 px-4 py-2.5 text-sm text-primary transition-colors hover:bg-primary/10"
	>
		<span class="flex items-center gap-2">
			<UploadFile class="text-[18px]" />
			<span class="font-bold">Kindle-Import</span>
			<span class="text-xs opacity-70">My Clippings.txt</span>
		</span>
		<span class="text-xs font-bold">&rarr;</span>
	</a>
</section>

<!-- Quick Add Bar -->
<section class="mt-4 px-0">
	<div class="flex items-center gap-2">
		<div
			class="flex h-12 flex-1 items-center overflow-hidden rounded-xl border border-primary/10 bg-primary/5 px-4 transition-all focus-within:border-primary/30"
		>
			<input
				type="text"
				bind:value={input}
				onkeydown={handleKeydown}
				class="min-w-0 flex-1 border-none bg-transparent p-0 text-base font-normal placeholder:text-primary/40 focus:ring-0"
				placeholder="Schnell hinzuf&uuml;gen..."
			/>
			<div class="flex items-center gap-1">
				<button class="p-1 text-primary/60 hover:text-primary">
					<PhotoCamera class="text-[20px]" />
				</button>
				<button class="p-1 text-primary/60 hover:text-primary">
					<Mic class="text-[20px]" />
				</button>
			</div>
		</div>
		<button
			onclick={handleAdd}
			disabled={adding || !input.trim()}
			class="flex size-12 items-center justify-center rounded-xl bg-primary text-white shadow-sm transition-colors hover:bg-primary/90 disabled:opacity-50"
		>
			<Add />
		</button>
	</div>

	{#if feedback}
		<div
			class="mt-2 rounded-xl border border-primary/20 bg-primary/5 px-4 py-2.5 text-sm text-primary"
		>
			Hinzugef&uuml;gt: <strong>{feedback.word}</strong>
			<span class="ml-1 text-xs opacity-70">[{feedback.language}]</span>
			{#if feedback.pinyin}
				<span class="ml-1 text-xs">&mdash; {feedback.pinyin}</span>
			{/if}
			{#if feedback.translation}
				<span class="ml-1 text-xs opacity-70">({feedback.translation})</span>
			{/if}
		</div>
	{/if}

	{#if errorMsg}
		<div class="mt-2 rounded-xl border border-red-200 bg-red-50 px-4 py-2.5 text-sm text-red-700 dark:border-red-800 dark:bg-red-950 dark:text-red-300">
			{errorMsg}
		</div>
	{/if}
</section>

<!-- Filter Chips -->
<section class="mt-4 flex gap-2 overflow-x-auto no-scrollbar">
	<button
		onclick={() => (filter = 'all')}
		class="flex h-9 shrink-0 items-center justify-center rounded-full px-5 text-sm font-semibold transition-colors {filter === 'all'
			? 'bg-primary text-white'
			: 'bg-slate-100 text-slate-600 dark:bg-white/10 dark:text-slate-300'}"
	>
		Alle
	</button>
	<button
		onclick={() => (filter = 'zh')}
		class="flex h-9 shrink-0 items-center justify-center rounded-full px-5 text-sm font-medium transition-colors {filter === 'zh'
			? 'bg-primary text-white'
			: 'bg-slate-100 text-slate-600 dark:bg-white/10 dark:text-slate-300'}"
	>
		中文
	</button>
	<button
		onclick={() => (filter = 'de')}
		class="flex h-9 shrink-0 items-center justify-center rounded-full px-5 text-sm font-medium transition-colors {filter === 'de'
			? 'bg-primary text-white'
			: 'bg-slate-100 text-slate-600 dark:bg-white/10 dark:text-slate-300'}"
	>
		Deutsch
	</button>
	<button
		onclick={() => (filter = 'en')}
		class="flex h-9 shrink-0 items-center justify-center rounded-full px-5 text-sm font-medium transition-colors {filter === 'en'
			? 'bg-primary text-white'
			: 'bg-slate-100 text-slate-600 dark:bg-white/10 dark:text-slate-300'}"
	>
		English
	</button>
</section>

<!-- Word List -->
<section class="mt-6 space-y-6">
	{#if filtered.length === 0}
		<div class="rounded-2xl border border-slate-100 dark:border-white/5 bg-white p-8 text-center shadow-sm dark:border-white/5 dark:bg-white/5">
			<Book2 class="mb-2 text-[32px] text-slate-300 dark:text-slate-500 dark:text-slate-400" />
			<p class="text-sm text-slate-500 dark:text-slate-400">
				Noch keine W&ouml;rter. F&uuml;ge W&ouml;rter hinzu, die dir beim Lesen begegnen.
			</p>
		</div>
	{:else}
		<!-- Word group -->
		<div>
			<h3 class="mb-3 px-1 text-[11px] font-bold uppercase tracking-wider text-primary">
				Lexikon ({filtered.length} W&ouml;rter)
			</h3>
			<div class="space-y-3">
				{#each filtered as entry (entry.id)}
					<div
						class="rounded-2xl border border-slate-100 dark:border-white/5 bg-white p-4 shadow-sm dark:border-white/5 dark:bg-slate-800/40"
					>
						{#if editingId === entry.id}
							<!-- Edit mode -->
							<div class="flex items-center gap-2">
								<input
									type="text"
									bind:value={editTranslation}
									onkeydown={handleEditKeydown}
									placeholder="&Uuml;bersetzung..."
									class="min-w-0 flex-1 rounded-lg border border-primary/20 bg-primary/5 px-3 py-2 text-sm text-slate-900 dark:text-slate-100 placeholder-primary/40 outline-none focus:border-primary/40 dark:text-slate-100"
								/>
								<button
									onclick={saveEdit}
									class="rounded-lg bg-primary p-2 text-white transition-colors hover:bg-primary/90"
								>
									<Check class="text-[18px]" />
								</button>
								<button
									onclick={cancelEdit}
									class="rounded-lg bg-slate-100 p-2 text-slate-500 dark:text-slate-400 transition-colors hover:bg-slate-200 dark:hover:bg-white/15 dark:bg-white/10 dark:text-slate-400 dark:hover:bg-white/15"
								>
									<Close class="text-[18px]" />
								</button>
							</div>
						{:else}
							<!-- Display mode -->
							<div class="flex items-center">
								<div class="min-w-0 flex-1">
									<div class="mb-0.5 flex items-center gap-2">
										{#if entry.language === 'zh'}
										<a
											href="/character/{encodeURIComponent(entry.word)}"
											class="chinese-char text-lg font-bold hover:text-primary"
										>{entry.word}</a>
									{:else if entry.language === 'ar'}
										<span dir="rtl" class="text-xl font-bold">{entry.word}</span>
									{:else}
										<span class="text-lg font-bold">{entry.word}</span>
									{/if}
										<span
											class="rounded bg-primary/5 px-1.5 py-0.5 text-[10px] font-bold text-primary"
										>
											{langTag(entry.language)}
										</span>
									</div>
									<p class="text-[13px] text-slate-500 dark:text-slate-400">
										{#if entry.pinyin}
											{entry.pinyin}
											{#if entry.translation} &bull; {/if}
										{/if}
										{#if entry.translation}
											{entry.translation}
										{:else if entry.reps === 0}
											Neu
										{:else}
											{entry.reps} Wiederholungen
										{/if}
									</p>
								</div>
								<div class="flex items-center gap-1">
									<button
										onclick={() => startEdit(entry)}
										class="rounded-lg p-1.5 text-slate-300 transition-colors hover:bg-slate-100 dark:hover:bg-white/10 hover:text-primary dark:text-slate-500 dark:text-slate-400 dark:hover:bg-white/10"
										title="Bearbeiten"
									>
										<Edit class="text-[18px]" />
									</button>
									<button
										onclick={() => handleRemove(entry.id)}
										class="rounded-lg p-1.5 text-slate-300 transition-colors hover:bg-red-50 hover:text-red-600 dark:text-slate-500 dark:text-slate-400 dark:hover:bg-red-950"
										title="Entfernen"
									>
										<Delete class="text-[18px]" />
									</button>
									<div
										class="ml-1 size-2.5 rounded-full {statusColor(entry)}"
										title={statusTitle(entry)}
									></div>
								</div>
							</div>
						{/if}
					</div>
				{/each}
			</div>
		</div>
	{/if}
</section>
