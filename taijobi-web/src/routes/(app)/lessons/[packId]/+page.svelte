<script lang="ts">
	import ExpandMore from '$lib/icons/ExpandMore.svelte';
	import PlayCircle from '$lib/icons/PlayCircle.svelte';
	import VolumeUp from '$lib/icons/VolumeUp.svelte';
	import {
		getLessons,
		getPackProgress,
		getVocabulary,
		getPacks,
		getCardById,
		type Lesson,
		type VocabEntry,
		type CardSearchResult
	} from '$lib/wasm';
	import { speak } from '$lib/speak';
	import { page } from '$app/state';
	import { tick } from 'svelte';

	let packId = $derived(page.params.packId ?? '');
	let lessons: Lesson[] = $state([]);
	let progress = $state({ total: 0, reviewed: 0, mastered: 0 });
	let expandedLesson = $state<string | null>(null);
	let vocabulary: VocabEntry[] = $state([]);
	let packName = $state('');
	let isChinese = $state(false);
	let isArabic = $state(false);
	let hasPinyin = $state(false);
	let highlightedCardId = $state<string | null>(null);
	let focusedCard = $state<CardSearchResult | null>(null);
	let deepLinkHandled = $state(false);

	function refresh() {
		if (!packId) return;
		lessons = getLessons(packId);
		progress = getPackProgress(packId);
		const pack = getPacks().find((p) => p.id === packId);
		packName = pack?.name ?? packId;
		isChinese = pack?.language_pair?.startsWith('zh') ?? false;
		isArabic = pack?.language_pair?.startsWith('ar') ?? false;
		hasPinyin = isChinese;
	}

	$effect(() => {
		if (packId) refresh();
	});

	// Honor `?lesson={id}&card={id}` from ⌘K: auto-expand the lesson and
	// scroll to the card row. If the card is past the 200-row vocabulary
	// limit and not in the rendered list, pin it at the top as a "focused"
	// banner so the user still sees the target they asked for.
	$effect(() => {
		if (deepLinkHandled || lessons.length === 0) return;
		const lessonParam = page.url.searchParams.get('lesson');
		const cardParam = page.url.searchParams.get('card');
		if (!lessonParam) {
			deepLinkHandled = true;
			return;
		}
		deepLinkHandled = true;
		const lesson = lessons.find((l) => l.id === lessonParam);
		if (!lesson) return;
		expandedLesson = lessonParam;
		vocabulary = getVocabulary(lessonParam);
		if (cardParam) {
			highlightedCardId = cardParam;
			void tick().then(() => {
				const inList = vocabulary.some((v) => v.id === cardParam);
				if (inList) {
					const el = document.getElementById(`card-${cardParam}`);
					if (el) el.scrollIntoView({ behavior: 'smooth', block: 'center' });
				} else {
					// Target is past LIMIT 200 — fetch it directly and pin at top.
					focusedCard = getCardById(cardParam);
					void tick().then(() => {
						const el = document.getElementById(`focused-card`);
						if (el) el.scrollIntoView({ behavior: 'smooth', block: 'center' });
					});
				}
				setTimeout(() => (highlightedCardId = null), 1800);
			});
		}
	});

	function toggleLesson(lessonId: string) {
		if (expandedLesson === lessonId) {
			expandedLesson = null;
			vocabulary = [];
		} else {
			expandedLesson = lessonId;
			vocabulary = getVocabulary(lessonId);
		}
	}

	function progressPercent(mastered: number, total: number): number {
		if (total === 0) return 0;
		return Math.round((mastered / total) * 100);
	}
</script>

<!-- Pack progress -->
<section class="mt-4">
	<div class="rounded-2xl border border-slate-100 bg-white p-4 shadow-sm dark:border-white/5 dark:bg-white/5">
		<div class="mb-3 flex items-center justify-between">
			<h2 class="text-lg font-bold text-slate-900 dark:text-slate-100">{packName}</h2>
			<span class="text-sm font-bold text-primary">{progressPercent(progress.mastered, progress.total)}%</span>
		</div>
		<div class="h-2.5 w-full overflow-hidden rounded-full bg-primary/20">
			<div
				class="h-full rounded-full bg-primary transition-all"
				style="width: {progressPercent(progress.mastered, progress.total)}%"
			></div>
		</div>
		<p class="mt-2 text-xs text-slate-500 dark:text-slate-400">
			{progress.mastered} / {progress.total} gemeistert
		</p>
	</div>
</section>

<!-- Focused card (deep-link target past the vocabulary LIMIT 200) -->
{#if focusedCard}
	<section
		id="focused-card"
		class="mt-4 rounded-2xl border-2 border-primary/40 bg-primary/5 p-4 shadow-sm ring-2 ring-primary/20"
	>
		<p class="mb-2 text-[11px] font-bold uppercase tracking-wider text-primary">Gesuchte Karte</p>
		<div class="flex items-start justify-between gap-3">
			<div class="min-w-0 flex-1">
				<p
					class="text-xl font-bold text-slate-900 dark:text-slate-100"
					class:chinese-char={isChinese}
					dir={isArabic ? 'rtl' : undefined}
				>
					{focusedCard.word}
				</p>
				{#if focusedCard.pinyin}
					<p class="text-sm text-primary/80">{focusedCard.pinyin}</p>
				{/if}
				{#if focusedCard.translation}
					<p class="mt-1 text-sm text-slate-600 dark:text-slate-300">{focusedCard.translation}</p>
				{/if}
				{#if focusedCard.context}
					<p class="mt-2 truncate text-xs italic text-slate-500 dark:text-slate-400">
						&bdquo;{focusedCard.context}&ldquo;
					</p>
				{/if}
				<p class="mt-2 text-xs text-slate-400 dark:text-slate-500">
					Außerhalb der ersten 200 Wörter dieser Lektion
				</p>
			</div>
			<div class="flex items-start gap-1">
				<button
					onclick={() =>
						focusedCard &&
						speak(focusedCard.word, isChinese ? 'zh' : isArabic ? 'ar' : focusedCard.language)}
					class="rounded-lg p-1.5 text-primary/60 transition-colors hover:bg-primary/10 hover:text-primary dark:hover:bg-primary/20"
					aria-label="Aussprechen"
				>
					<VolumeUp class="text-[20px]" />
				</button>
				<button
					onclick={() => (focusedCard = null)}
					class="rounded-lg p-1.5 text-slate-400 transition-colors hover:bg-slate-100 hover:text-slate-600 dark:hover:bg-white/10"
					aria-label="Schließen"
				>
					<span class="text-lg leading-none">×</span>
				</button>
			</div>
		</div>
	</section>
{/if}

<!-- Lessons -->
<section class="mt-6 space-y-3">
	{#each lessons as lesson (lesson.id)}
		<div class="overflow-hidden rounded-2xl border border-slate-100 bg-white shadow-sm dark:border-white/5 dark:bg-white/5">
			<!-- Lesson header -->
			<button
				onclick={() => toggleLesson(lesson.id)}
				class="flex w-full items-center justify-between p-4 text-left transition-colors hover:bg-primary/5"
			>
				<div class="flex items-center gap-3">
					<span class="rounded bg-primary/10 px-1.5 py-0.5 text-[10px] font-bold text-primary">
						L{lesson.sort_order}
					</span>
					<div>
						<p class="font-bold text-slate-900 dark:text-slate-100">{lesson.title ?? `Lektion ${lesson.sort_order}`}</p>
						<p class="text-xs text-slate-500 dark:text-slate-400">
							{lesson.mastered}/{lesson.total} gemeistert &bull; {progressPercent(lesson.mastered, lesson.total)}%
						</p>
					</div>
				</div>
				<ExpandMore class="text-primary transition-transform {expandedLesson === lesson.id ? 'rotate-180' : ''}" />
			</button>

			<!-- Expanded vocabulary -->
			{#if expandedLesson === lesson.id}
				<div class="border-t border-slate-100 dark:border-white/5 p-4">
					<!-- Progress bar -->
					<div class="mb-4 h-1.5 w-full overflow-hidden rounded-full bg-primary/20">
						<div
							class="h-full rounded-full bg-primary"
							style="width: {progressPercent(lesson.mastered, lesson.total)}%"
						></div>
					</div>

					<!-- Vocab table -->
					<div class="overflow-hidden rounded-lg border border-primary/10">
						<table class="w-full text-left text-sm">
							<thead class="bg-primary/5 text-[10px] font-bold uppercase tracking-wider text-primary">
								<tr>
									<th class="px-3 py-2">{isChinese ? 'Hanzi' : 'Wort'}</th>
									{#if hasPinyin}
										<th class="px-3 py-2">Pinyin</th>
									{/if}
									<th class="px-3 py-2">{isChinese ? 'Deutsch' : 'Übersetzung'}</th>
									<th class="w-10 px-2 py-2"></th>
								</tr>
							</thead>
							<tbody class="divide-y divide-primary/5">
								{#each vocabulary as word (word.id)}
									<tr
										id="card-{word.id}"
										class="transition-colors {highlightedCardId === word.id
											? 'bg-primary/15 dark:bg-primary/25'
											: 'bg-white/50 dark:bg-white/5'}"
									>
										<td class="px-3 py-2 font-medium text-slate-900 dark:text-slate-100" class:chinese-char={isChinese} class:text-lg={isArabic} dir={isArabic ? 'rtl' : undefined}>
											{#if isChinese}
												<a href="/character/{encodeURIComponent(word.word)}" class="hover:text-primary">{word.word}</a>
											{:else}
												{word.word}
											{/if}
										</td>
										{#if hasPinyin}
											<td class="px-3 py-2 text-primary/80">{word.pinyin ?? ''}</td>
										{/if}
										<td class="max-w-[200px] truncate px-3 py-2 text-slate-700 dark:text-slate-300">{word.translation ?? ''}</td>
										<td class="px-2 py-2">
											<button
												onclick={() => speak(word.word, isChinese ? 'zh' : isArabic ? 'ar' : 'en')}
												class="text-primary/40 hover:text-primary"
											>
												<VolumeUp class="text-[18px]" />
											</button>
										</td>
									</tr>
								{/each}
							</tbody>
						</table>
					</div>

					{#if vocabulary.length >= 200}
						<p class="mt-2 text-center text-xs text-slate-400 dark:text-slate-500">
							Erste 200 von {lesson.total} Wörtern
						</p>
					{/if}

					<!-- Drill button -->
					<a
						href="/drill"
						class="mt-4 flex w-full items-center justify-center gap-2 rounded-xl bg-primary py-3 font-bold text-white shadow-lg shadow-primary/20 transition-all hover:bg-primary/90"
					>
						<PlayCircle />
						Drill starten
					</a>
				</div>
			{/if}
		</div>
	{/each}
</section>

{#if lessons.length === 0}
	<div class="mt-8 rounded-2xl border border-slate-100 bg-white p-8 text-center shadow-sm dark:border-white/5 dark:bg-white/5">
		<p class="text-sm text-slate-500 dark:text-slate-400">Keine Lektionen gefunden.</p>
		<a href="/packs" class="mt-2 text-sm font-medium text-primary">Zur&uuml;ck zu Paketen</a>
	</div>
{/if}
