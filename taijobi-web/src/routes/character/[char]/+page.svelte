<script lang="ts">
	import { page } from '$app/state';
	import {
		decompose,
		getStrokes,
		lookupCedict,
		getLexicon,
		type DecompResult,
		type StrokeData,
		type DecompComponent,
		type LexiconEntry,
	} from '$lib/wasm';
	import { speak } from '$lib/speak';

	let char = $derived(decodeURIComponent(page.params.char ?? ''));
	let decompData: DecompResult | null = $state(null);
	let strokeData: StrokeData | null = $state(null);
	let relatedWords: LexiconEntry[] = $state([]);
	let animating = $state(false);
	let animationFrame = $state(-1);

	$effect(() => {
		if (!char) return;
		decompData = decompose(char);
		strokeData = getStrokes(char);

		// Find words containing this character in user's lexicon
		const allWords = getLexicon();
		relatedWords = allWords.filter((w) => w.word.includes(char));
	});

	function playAnimation() {
		if (!strokeData || animating) return;
		animating = true;
		animationFrame = 0;
		const interval = setInterval(() => {
			animationFrame++;
			if (animationFrame >= strokeData!.stroke_count) {
				clearInterval(interval);
				animating = false;
			}
		}, 600);
	}

	function componentLabel(type: string): string {
		switch (type) {
			case 'radical':
				return 'Radikal';
			default:
				return 'Komponente';
		}
	}

	function strokeViewBox(): string {
		return '0 0 1024 1024';
	}
</script>

<section class="mt-4">
	<!-- Breadcrumb -->
	<div class="mb-4 flex items-center gap-2 text-sm text-slate-500">
		<a href="/" class="hover:text-primary">Lernen</a>
		<span>&rsaquo;</span>
		<span class="font-medium text-slate-900">{char}</span>
	</div>

	<!-- Hero Section -->
	<div class="rounded-2xl border border-slate-100 bg-[#fdfaf3] p-6 shadow-sm">
		<div class="flex items-start justify-between">
			<div class="flex-1 text-center">
				<h1 class="chinese-char text-[96px] font-light leading-none text-slate-900">
					{char}
				</h1>
				{#if decompData}
					<p class="mt-2 text-lg font-medium text-primary">{decompData.pinyin}</p>
					<p class="mt-1 text-sm text-slate-600">{decompData.definition}</p>
				{/if}
			</div>
			<button
				onclick={() => speak(char, 'zh')}
				class="flex items-center justify-center rounded-full bg-primary/10 p-2 text-primary transition-colors hover:bg-primary/20"
			>
				<span class="material-symbols-outlined text-xl">volume_up</span>
			</button>
		</div>
	</div>
</section>

<!-- Components Section -->
{#if decompData && decompData.components.length > 0}
	<section class="mt-6">
		<h3 class="mb-3 text-[11px] font-bold uppercase tracking-wider text-primary">
			Komponenten
		</h3>
		{#if decompData.decomposition}
			<p class="mb-3 text-sm text-slate-500">
				Zerlegung: <span class="font-mono text-slate-700">{decompData.decomposition}</span>
			</p>
		{/if}
		<div class="flex flex-wrap gap-3">
			{#each decompData.components as comp (comp.char)}
				<a
					href="/character/{encodeURIComponent(comp.char)}"
					class="flex min-w-[80px] flex-col items-center rounded-xl border border-slate-100 bg-white p-3 shadow-sm transition-colors hover:border-primary/20 hover:bg-primary/5"
				>
					<span class="chinese-char text-2xl {comp.type === 'radical' ? 'text-primary' : 'text-slate-900'}">
						{comp.char}
					</span>
					<span class="mt-1 text-[10px] font-bold uppercase tracking-wider {comp.type === 'radical' ? 'text-primary' : 'text-slate-400'}">
						{componentLabel(comp.type)}
					</span>
					{#if comp.definition}
						<span class="mt-0.5 text-center text-xs text-slate-500">
							{comp.definition.length > 30 ? comp.definition.slice(0, 30) + '...' : comp.definition}
						</span>
					{/if}
				</a>
			{/each}
		</div>
		{#if decompData.etymology_hint}
			<p class="mt-3 text-sm text-slate-500">
				<span class="font-medium text-slate-600">{decompData.etymology_type}:</span>
				{decompData.etymology_hint}
			</p>
		{/if}
	</section>
{/if}

<!-- Stroke Order Section -->
{#if strokeData}
	<section class="mt-6">
		<h3 class="mb-3 text-[11px] font-bold uppercase tracking-wider text-primary">
			Strichfolge
		</h3>
		<div class="rounded-2xl border border-slate-100 bg-white p-4 shadow-sm">
			<div class="mx-auto flex max-w-[200px] items-center justify-center">
				<svg viewBox={strokeViewBox()} class="h-[200px] w-[200px]">
					<!-- Crosshair guides -->
					<line x1="512" y1="0" x2="512" y2="1024" stroke="#e2e8f0" stroke-width="1" stroke-dasharray="8,8" />
					<line x1="0" y1="512" x2="1024" y2="512" stroke="#e2e8f0" stroke-width="1" stroke-dasharray="8,8" />
					<line x1="0" y1="0" x2="1024" y2="1024" stroke="#e2e8f0" stroke-width="0.5" stroke-dasharray="8,8" />
					<line x1="1024" y1="0" x2="0" y2="1024" stroke="#e2e8f0" stroke-width="0.5" stroke-dasharray="8,8" />

					<!-- Border -->
					<rect x="2" y="2" width="1020" height="1020" fill="none" stroke="#e2e8f0" stroke-width="2" stroke-dasharray="8,8" rx="4" />

					<!-- Strokes -->
					{#each strokeData.strokes as stroke, i}
						<path
							d={stroke}
							fill={animating
								? i < animationFrame
									? '#195c37'
									: i === animationFrame
										? '#52b788'
										: '#e2e8f0'
								: '#195c37'}
							stroke="none"
							class="transition-all duration-300"
						/>
					{/each}
				</svg>
			</div>

			<div class="mt-3 flex items-center justify-center gap-3">
				<button
					onclick={playAnimation}
					disabled={animating}
					class="flex items-center gap-1.5 rounded-lg bg-primary px-4 py-2 text-sm font-medium text-white transition-colors hover:bg-primary/90 disabled:opacity-50"
				>
					<span class="material-symbols-outlined text-[18px]">play_arrow</span>
					Animation
				</button>
				<span class="text-sm text-slate-500">{strokeData.stroke_count} Striche</span>
			</div>
		</div>
	</section>
{/if}

<!-- Related Words in Vocabulary -->
{#if relatedWords.length > 0}
	<section class="mt-6">
		<h3 class="mb-3 text-[11px] font-bold uppercase tracking-wider text-primary">
			In deinem Vokabular
		</h3>
		<div class="space-y-2">
			{#each relatedWords as word (word.id)}
				<div class="flex items-center justify-between rounded-xl border border-slate-100 bg-white px-4 py-3 shadow-sm">
					<div>
						<span class="chinese-char text-lg font-medium">{word.word}</span>
						{#if word.pinyin}
							<span class="ml-2 text-sm text-primary/80">{word.pinyin}</span>
						{/if}
						{#if word.translation}
							<span class="ml-2 text-sm text-slate-500">{word.translation}</span>
						{/if}
					</div>
					<div class="flex items-center gap-2">
						{#if word.reps > 0}
							<span class="text-xs text-slate-400">{word.reps}x</span>
						{/if}
						<button
							onclick={() => speak(word.word, 'zh')}
							class="text-primary/40 hover:text-primary"
						>
							<span class="material-symbols-outlined text-[18px]">volume_up</span>
						</button>
					</div>
				</div>
			{/each}
		</div>
	</section>
{/if}

<!-- Bottom padding -->
<div class="h-8"></div>
