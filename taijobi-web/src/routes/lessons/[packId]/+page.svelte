<script lang="ts">
	import { getLessons, getPackProgress, getVocabulary, type Lesson, type VocabEntry } from '$lib/wasm';
	import { speak } from '$lib/speak';
	import { page } from '$app/state';

	let packId = $derived(page.params.packId ?? '');
	let lessons: Lesson[] = $state([]);
	let progress = $state({ total: 0, reviewed: 0, mastered: 0 });
	let expandedLesson = $state<string | null>(null);
	let vocabulary: VocabEntry[] = $state([]);

	function refresh() {
		if (!packId) return;
		lessons = getLessons(packId);
		progress = getPackProgress(packId);
	}

	$effect(() => {
		if (packId) refresh();
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
	<div class="rounded-2xl border border-slate-100 bg-white p-4 shadow-sm">
		<div class="mb-3 flex items-center justify-between">
			<h2 class="text-lg font-bold text-slate-900">{packId}</h2>
			<span class="text-sm font-bold text-primary">{progressPercent(progress.mastered, progress.total)}%</span>
		</div>
		<div class="h-2.5 w-full overflow-hidden rounded-full bg-primary/20">
			<div
				class="h-full rounded-full bg-primary transition-all"
				style="width: {progressPercent(progress.mastered, progress.total)}%"
			></div>
		</div>
		<p class="mt-2 text-xs text-slate-500">
			{progress.mastered} / {progress.total} gemeistert
		</p>
	</div>
</section>

<!-- Lessons -->
<section class="mt-6 space-y-3">
	{#each lessons as lesson (lesson.id)}
		<div class="overflow-hidden rounded-2xl border border-slate-100 bg-white shadow-sm">
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
						<p class="font-bold text-slate-900">{lesson.title ?? `Lektion ${lesson.sort_order}`}</p>
						<p class="text-xs text-slate-500">
							{lesson.mastered}/{lesson.total} gemeistert &bull; {progressPercent(lesson.mastered, lesson.total)}%
						</p>
					</div>
				</div>
				<span
					class="material-symbols-outlined text-primary transition-transform {expandedLesson === lesson.id ? 'rotate-180' : ''}"
				>
					expand_more
				</span>
			</button>

			<!-- Expanded vocabulary -->
			{#if expandedLesson === lesson.id}
				<div class="border-t border-slate-100 p-4">
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
									<th class="px-3 py-2">Hanzi</th>
									<th class="px-3 py-2">Pinyin</th>
									<th class="px-3 py-2">Deutsch</th>
									<th class="w-10 px-2 py-2"></th>
								</tr>
							</thead>
							<tbody class="divide-y divide-primary/5">
								{#each vocabulary as word (word.id)}
									<tr class="bg-white/50">
										<td class="chinese-char px-3 py-2 font-medium">{word.word}</td>
										<td class="px-3 py-2 text-primary/80">{word.pinyin ?? ''}</td>
										<td class="px-3 py-2">{word.translation ?? ''}</td>
										<td class="px-2 py-2">
											<button
												onclick={() => speak(word.word, 'zh')}
												class="text-primary/40 hover:text-primary"
											>
												<span class="material-symbols-outlined text-[18px]">volume_up</span>
											</button>
										</td>
									</tr>
								{/each}
							</tbody>
						</table>
					</div>

					<!-- Drill button -->
					<a
						href="/drill"
						class="mt-4 flex w-full items-center justify-center gap-2 rounded-xl bg-primary py-3 font-bold text-white shadow-lg shadow-primary/20 transition-all hover:bg-primary/90"
					>
						<span class="material-symbols-outlined">play_circle</span>
						Drill starten
					</a>
				</div>
			{/if}
		</div>
	{/each}
</section>

{#if lessons.length === 0}
	<div class="mt-8 rounded-2xl border border-slate-100 bg-white p-8 text-center shadow-sm">
		<p class="text-sm text-slate-500">Keine Lektionen gefunden.</p>
		<a href="/packs" class="mt-2 text-sm font-medium text-primary">Zur&uuml;ck zu Paketen</a>
	</div>
{/if}
