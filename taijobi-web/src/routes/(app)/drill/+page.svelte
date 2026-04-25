<script lang="ts">
	import ArrowBack from '$lib/icons/ArrowBack.svelte';
	import AutoStories from '$lib/icons/AutoStories.svelte';
	import CheckCircle from '$lib/icons/CheckCircle.svelte';
	import Close from '$lib/icons/Close.svelte';
	import Delete from '$lib/icons/Delete.svelte';
	import FastForward from '$lib/icons/FastForward.svelte';
	import VolumeUp from '$lib/icons/VolumeUp.svelte';
	import Icon from '$lib/icons/Icon.svelte';
	import { pushStore } from '$lib/push.svelte';
	import {
		getDueCards,
		getDueCardsFiltered,
		getDueCountFiltered,
		getUpcomingCards,
		getUnreadCards,
		getUnreadCount,
		markRead,
		getPacks,
		reviewCard,
		removeWord,
		checkAnswer,
		type Card,
		type Pack,
		type ReadCard
	} from '$lib/wasm';
	import { speak } from '$lib/speak';
	import { haptics } from '$lib/haptics';
	import { data } from '$lib/data.svelte';
	import { page } from '$app/state';
	import { untrack } from 'svelte';
	import { SS_DRILL_SESSION } from '$lib/config';

	type DrillPhase = 'picking' | 'question' | 'answer' | 'complete' | 'reading';
	type DrillDirection = 'zh-de' | 'de-zh' | 'zh-pinyin';

	let cards: Card[] = $state([]);
	let index = $state(0);
	let phase: DrillPhase = $state('picking');
	let input = $state('');
	let reviewed = $state(0);
	let activeFilter = $state('');
	let filterLabel = $state('');
	let direction: DrillDirection = $state('zh-de');
	let answerCorrect: boolean | null = $state(null);
	let remainingDue = $state(0);
	let remainingUnread = $state(0);
	let upcomingCount = $state(0);

	// "Peek back" at previously reviewed card (read-only)
	let peekCard: Card | null = $state(null);
	let isPeeking = $state(false);

	// Reading mode state
	let readCards: ReadCard[] = $state([]);
	let readIndex = $state(0);
	let readingDone = $state(false);
	let readCount = $state(0);

	// --- Session persistence (survives page reload) ---

	interface DrillSession {
		cards: Card[];
		index: number;
		phase: DrillPhase;
		reviewed: number;
		activeFilter: string;
		filterLabel: string;
		direction: DrillDirection;
		// Reading mode
		readCards?: ReadCard[];
		readIndex?: number;
		readCount?: number;
		readingDone?: boolean;
	}

	function saveSession() {
		if (phase === 'picking' || phase === 'complete') {
			sessionStorage.removeItem(SS_DRILL_SESSION);
			return;
		}
		const session: DrillSession = {
			cards, index, phase, reviewed, activeFilter, filterLabel, direction,
		};
		if (phase === 'reading') {
			session.readCards = readCards;
			session.readIndex = readIndex;
			session.readCount = readCount;
			session.readingDone = readingDone;
		}
		try {
			sessionStorage.setItem(SS_DRILL_SESSION, JSON.stringify(session));
		} catch { /* quota exceeded — non-critical */ }
	}

	function restoreSession(): boolean {
		try {
			const raw = sessionStorage.getItem(SS_DRILL_SESSION);
			if (!raw) return false;
			const s: DrillSession = JSON.parse(raw);
			if (!s.cards?.length && !s.readCards?.length) return false;

			cards = s.cards ?? [];
			index = s.index;
			phase = s.phase;
			reviewed = s.reviewed;
			activeFilter = s.activeFilter;
			filterLabel = s.filterLabel;
			direction = s.direction;

			if (s.readCards) {
				readCards = s.readCards;
				readIndex = s.readIndex ?? 0;
				readCount = s.readCount ?? 0;
				readingDone = s.readingDone ?? false;
			}

			return true;
		} catch {
			sessionStorage.removeItem(SS_DRILL_SESSION);
			return false;
		}
	}

	function clearSession() {
		sessionStorage.removeItem(SS_DRILL_SESSION);
	}

	// Sources for the picker
	let packs: Pack[] = $state([]);

	interface DrillSource {
		id: string;
		label: string;
		count: number;
	}

	interface ReadSource {
		id: string;
		label: string;
		count: number;
	}

	let sources: DrillSource[] = $state([]);
	let readSources: ReadSource[] = $state([]);

	function buildSources() {
		packs = getPacks();
		const all: DrillSource[] = [];
		const reads: ReadSource[] = [];

		// Build unread sources
		const totalUnread = getUnreadCount('');
		if (totalUnread > 0) reads.push({ id: '', label: 'Alle Karten', count: totalUnread });

		for (const pack of packs) {
			const unread = getUnreadCount(pack.id);
			if (unread > 0) reads.push({ id: pack.id, label: pack.name, count: unread });
		}

		const lexUnread = getUnreadCount('lexicon');
		if (lexUnread > 0) reads.push({ id: 'lexicon', label: 'Lexikon', count: lexUnread });

		readSources = reads;

		// Build due sources
		const totalDue = getDueCountFiltered('');
		if (totalDue > 0) all.push({ id: '', label: 'Alle Karten', count: totalDue });

		for (const pack of packs) {
			const count = getDueCountFiltered(pack.id);
			if (count > 0) all.push({ id: pack.id, label: pack.name, count });
		}

		const lexCount = getDueCountFiltered('lexicon');
		if (lexCount > 0) all.push({ id: 'lexicon', label: 'Lexikon', count: lexCount });

		sources = all;
	}

	// If navigated with ?pack=xxx, skip picker
	function init() {
		const urlFilter = page.url.searchParams.get('pack');
		console.log('[drill] init, urlFilter:', urlFilter, 'url:', page.url.pathname + page.url.search);
		if (urlFilter) {
			startDrill(urlFilter, urlFilter);
			// /lessons/[packId] sends here for both "due" and "Karten
			// vorziehen" CTAs. If nothing is due, fall through to
			// pull-forward instead of dead-ending on an empty
			// "Sitzung abgeschlossen" screen.
			if (cards.length === 0) {
				startUpcoming();
			}
		} else if (restoreSession()) {
			console.log('[drill] restored session, phase:', phase, 'index:', index);
		} else {
			buildSources();
			phase = 'picking';
		}
	}

	init();

	// Re-build sources when sync pulls new data (only if on picker)
	$effect(() => {
		data.packs(); // reactive dependency — re-runs when data changes
		untrack(() => {
			if (phase === 'picking') buildSources();
		});
	});

	function startDrill(filter: string, label: string) {
		activeFilter = filter;
		filterLabel = label;
		cards = filter ? getDueCardsFiltered(filter, 50) : getDueCards(50);
		index = 0;
		phase = cards.length > 0 ? 'question' : 'complete';
		input = '';
		reviewed = 0;
		answerCorrect = null;
		peekCard = null;
		isPeeking = false;
		saveSession();
	}

	function startUpcoming() {
		cards = getUpcomingCards(activeFilter, 50, 24);
		index = 0;
		phase = cards.length > 0 ? 'question' : 'complete';
		input = '';
		reviewed = 0;
		answerCorrect = null;
		peekCard = null;
		isPeeking = false;
		saveSession();
	}

	function startReading(filter: string, label: string) {
		activeFilter = filter;
		filterLabel = label;
		readCards = getUnreadCards(filter, 50);
		readIndex = 0;
		readingDone = false;
		readCount = 0;
		phase = readCards.length > 0 ? 'reading' : 'picking';
		saveSession();
	}

	async function nextReadCard() {
		const rc = readCards[readIndex];
		if (rc) {
			await markRead(rc.id);
			readCount++;
		}
		readIndex++;
		if (readIndex >= readCards.length) {
			readingDone = true;
			remainingUnread = getUnreadCount(activeFilter);
			phase = 'complete';
		}
		saveSession();
	}

	let card = $derived(isPeeking ? peekCard : (cards[index] as Card | undefined));
	let total = $derived(cards.length);

	// What to show as the question
	let questionText = $derived.by(() => {
		if (!card) return '';
		if (direction === 'de-zh') return card.translation ?? card.word;
		return card.word;
	});

	// What's the expected answer
	let expectedAnswer = $derived.by(() => {
		if (!card) return '';
		if (direction === 'zh-de') return card.translation ?? '';
		if (direction === 'de-zh') return card.word;
		if (direction === 'zh-pinyin') return card.pinyin ?? '';
		return card.translation ?? '';
	});

	// Is question Chinese (for display sizing)?
	let questionIsChinese = $derived(
		card?.language === 'zh' && (direction as DrillDirection) !== 'de-zh' && hasChinese(questionText)
	);

	let questionIsArabic = $derived(
		card?.language === 'ar' && hasArabic(questionText)
	);

	// Self-assessment mode: for non-CJK cards with long definitions, skip typing
	let selfAssessMode = $derived(
		card != null &&
		card.language !== 'zh' &&
		!hasChinese(card.word) &&
		(card.translation?.length ?? 0) > 50
	);

	function reveal() {
		if (phase !== 'question') return;
		// In self-assess mode, skip answer checking
		if (selfAssessMode) {
			answerCorrect = null;
			phase = 'answer';
			return;
		}
		// Check the answer
		if (input.trim() && expectedAnswer) {
			const lang = direction === 'zh-pinyin' ? 'pinyin' : direction === 'zh-de' ? 'de' : 'zh';
			const result = checkAnswer(input, expectedAnswer, lang);
			answerCorrect = result.correct;
			if (answerCorrect) haptics.success();
			else haptics.error();
		} else {
			answerCorrect = null;
			haptics.tap();
		}
		phase = 'answer';
	}

	async function rate(rating: number) {
		if (!card) return;
		if (rating === 1) haptics.error();
		else if (rating >= 3) haptics.success();
		else haptics.medium();
		peekCard = card;
		await reviewCard(card.id, rating);
		// Update the server's last-review timestamp so the push-notification
		// cron knows we're active — fire-and-forget, never blocks the drill.
		pushStore.heartbeat();
		reviewed++;
		index++;
		input = '';
		answerCorrect = null;
		if (index >= total) {
			remainingDue = getDueCountFiltered(activeFilter);
			upcomingCount = getUpcomingCards(activeFilter, 1, 24).length;
			phase = 'complete';
		} else {
			phase = 'question';
		}
		saveSession();
	}

	function goBack() {
		if (!peekCard || phase === 'picking' || phase === 'complete') return;
		isPeeking = true;
		phase = 'answer';
	}

	function dismissPeek() {
		isPeeking = false;
		if (index >= total) {
			phase = 'complete';
		} else {
			phase = 'question';
		}
	}

	async function handleRemoveCard() {
		if (!card) return;
		const cardId = card.id;
		try {
			await removeWord(cardId);
			// Skip to next card without rating
			index++;
			input = '';
			answerCorrect = null;
			if (index >= total) {
				remainingDue = getDueCountFiltered(activeFilter);
			upcomingCount = getUpcomingCards(activeFilter, 1, 24).length;
				phase = 'complete';
			} else {
				phase = 'question';
			}
			saveSession();
		} catch (e) {
			console.error('[drill] remove failed:', e);
		}
	}

	function formatInterval(days: number): string {
		if (days < 1) return '<1d';
		if (days < 30) return `${Math.round(days)}d`;
		if (days < 365) return `${Math.round(days / 30)}mo`;
		return `${(days / 365).toFixed(1)}y`;
	}

	function handleKeydown(e: KeyboardEvent) {
		if (phase === 'question' && (e.key === 'Enter' || (selfAssessMode && e.key === ' '))) {
			reveal();
		} else if (phase === 'question' && e.key === 'ArrowLeft') {
			goBack();
		} else if (phase === 'answer') {
			if (isPeeking) {
				// Any key dismisses peek
				if (e.key === 'Enter' || e.key === 'ArrowRight' || e.key === 'Escape' || e.key === ' ') {
					dismissPeek();
				}
			} else {
				if (e.key === '1') rate(1);
				else if (e.key === '2') rate(2);
				else if (e.key === '3') rate(3);
				else if (e.key === '4') rate(4);
			}
		} else if (phase === 'reading' && (e.key === 'Enter' || e.key === 'ArrowRight')) {
			nextReadCard();
		}
	}

	let readCard = $derived(readCards[readIndex] as ReadCard | undefined);
	let readQuestionIsChinese = $derived(readCard ? hasChinese(readCard.word) : false);
	let readQuestionIsArabic = $derived(readCard ? hasArabic(readCard.word) : false);

	/** Split Chinese text into individual characters for tappable links */
	function splitChineseChars(text: string): string[] {
		return [...text];
	}

	function isChinese(char: string): boolean {
		const code = char.codePointAt(0) ?? 0;
		return (code >= 0x4E00 && code <= 0x9FFF) ||
			(code >= 0x3400 && code <= 0x4DBF) ||
			(code >= 0x20000 && code <= 0x2A6DF);
	}

	function hasChinese(text: string): boolean {
		return [...text].some(isChinese);
	}

	function isArabic(char: string): boolean {
		const code = char.codePointAt(0) ?? 0;
		return (code >= 0x0600 && code <= 0x06FF) ||
			(code >= 0x0750 && code <= 0x077F) ||
			(code >= 0x08A0 && code <= 0x08FF) ||
			(code >= 0xFB50 && code <= 0xFDFF);
	}

	function hasArabic(text: string): boolean {
		return [...text].some(isArabic);
	}

	const directions: { id: DrillDirection; label: string }[] = [
		{ id: 'zh-de', label: 'ZH → DE' },
		{ id: 'de-zh', label: 'DE → ZH' },
		{ id: 'zh-pinyin', label: 'ZH → Pinyin' },
	];
</script>

<svelte:window onkeydown={handleKeydown} />

{#if phase === 'picking'}
	<!-- Direction picker -->
	<section class="mt-4">
		<h3 class="mb-2 text-[11px] font-bold uppercase tracking-wider text-primary">Richtung</h3>
		<div class="flex gap-2">
			{#each directions as dir (dir.id)}
				<button
					onclick={() => (direction = dir.id)}
					class="rounded-full px-4 py-1.5 text-sm font-medium transition-colors {direction === dir.id
						? 'bg-primary text-white'
						: 'bg-slate-100 dark:bg-white/10 text-slate-600 dark:text-slate-300 hover:bg-slate-200 dark:hover:bg-white/15'}"
				>
					{dir.label}
				</button>
			{/each}
		</div>
	</section>

	<!-- Read new words -->
	{#if readSources.length > 0}
		<section class="mt-6">
			<h3 class="mb-2 text-[11px] font-bold uppercase tracking-wider text-primary">Neue W&ouml;rter durchlesen</h3>
			<div class="space-y-3">
				{#each readSources as source (source.id)}
					<button
						onclick={() => startReading(source.id, source.label)}
						class="flex w-full items-center justify-between rounded-2xl border border-primary/20 bg-primary-light p-4 shadow-sm transition-colors hover:bg-primary/10 dark:border-primary/30 dark:bg-primary/10 dark:hover:bg-primary/20"
					>
						<div class="flex items-center gap-3">
							<AutoStories class="text-primary" />
							<span class="font-bold text-slate-900 dark:text-slate-100">{source.label}</span>
						</div>
						<span class="rounded-full bg-primary/10 px-3 py-1 text-sm font-bold text-primary dark:bg-primary/20">
							{source.count} neu
						</span>
					</button>
				{/each}
			</div>
		</section>
	{/if}

	<!-- Source picker -->
	<section class="mt-6">
		<h3 class="mb-2 text-[11px] font-bold uppercase tracking-wider text-primary">F&auml;llige Karten</h3>
		<div class="space-y-3">
			{#each sources as source (source.id)}
				<button
					onclick={() => startDrill(source.id, source.label)}
					class="flex w-full items-center justify-between rounded-2xl border border-slate-100 bg-white p-4 shadow-sm transition-colors hover:bg-primary/5 dark:border-white/5 dark:bg-white/5"
				>
					<div class="flex items-center gap-3">
						<Icon name={source.id === '' ? 'layers' : source.id === 'lexicon' ? 'book' : 'inventory_2'} class="text-primary" />
						<span class="font-bold text-slate-900 dark:text-slate-100">{source.label}</span>
					</div>
					<span class="rounded-full bg-primary/10 px-3 py-1 text-sm font-bold text-primary">
						{source.count}
					</span>
				</button>
			{/each}
		</div>
		{#if sources.length === 0 && readSources.length === 0}
			<div class="rounded-2xl border border-slate-100 bg-white p-8 text-center shadow-sm dark:border-white/5 dark:bg-white/5">
				<p class="text-2xl font-bold text-slate-900 dark:text-slate-100">Alles erledigt!</p>
				<p class="mt-2 text-sm text-slate-500 dark:text-slate-400">Keine Karten f&auml;llig.</p>
			</div>
		{/if}
	</section>
{:else if phase === 'reading' && readCard}
	<!-- Reading mode -->
	<div class="mb-8 mt-4 text-center">
		{#if filterLabel}
			<p class="mb-1 text-xs font-bold uppercase tracking-wider text-primary">{filterLabel}</p>
		{/if}
		<p class="text-lg font-bold text-slate-900 dark:text-slate-100">{readIndex + 1} / {readCards.length}</p>
		<div class="mx-auto mt-2 h-1.5 w-48 overflow-hidden rounded-full bg-slate-100 dark:bg-white/10">
			<div class="h-full rounded-full bg-primary transition-all" style="width: {((readIndex + 1) / readCards.length) * 100}%"></div>
		</div>
	</div>

	<div class="flex flex-col items-center justify-center">
		<div class="mb-6 text-center">
			{#if readQuestionIsChinese}
				<h1 class="chinese-char mb-2 text-6xl font-bold tracking-tight text-slate-900 dark:text-slate-100">
					{readCard.word}
				</h1>
				{#if readCard.pinyin}
					<div class="flex items-center justify-center gap-3">
						<p class="text-lg font-medium text-primary">{readCard.pinyin}</p>
						<button
							onclick={() => speak(readCard!.word, readCard!.language)}
							class="flex items-center justify-center rounded-full bg-primary/10 p-2 text-primary transition-colors hover:bg-primary/20"
						>
							<VolumeUp class="text-xl" />
						</button>
					</div>
				{:else}
					<button
						onclick={() => speak(readCard!.word, readCard!.language)}
						class="mt-2 flex items-center justify-center rounded-full bg-primary/10 p-2 text-primary transition-colors hover:bg-primary/20"
					>
						<VolumeUp class="text-xl" />
					</button>
				{/if}
			{:else if readQuestionIsArabic}
				<h1 dir="rtl" class="mb-2 text-5xl font-bold leading-relaxed tracking-tight text-slate-900 dark:text-slate-100">
					{readCard.word}
				</h1>
				<button
					onclick={() => speak(readCard!.word, readCard!.language)}
					class="mt-2 flex items-center justify-center rounded-full bg-primary/10 p-2 text-primary transition-colors hover:bg-primary/20"
				>
					<VolumeUp class="text-xl" />
				</button>
			{:else}
				<div class="flex items-center justify-center gap-3">
					<h1 class="{readCard.word.length > 60 ? 'text-lg' : readCard.word.length > 30 ? 'text-2xl' : 'text-4xl'} font-bold tracking-tight text-slate-900 dark:text-slate-100">{readCard.word}</h1>
					<button
						onclick={() => speak(readCard!.word, readCard!.language)}
						class="flex items-center justify-center rounded-full bg-primary/10 p-2 text-primary transition-colors hover:bg-primary/20"
					>
						<VolumeUp class="text-xl" />
					</button>
				</div>
			{/if}
		</div>

		<!-- Translation (always visible in reading mode) -->
		<div class="mb-8 w-full max-w-md rounded-xl border-2 border-primary/20 bg-primary-light p-4 text-center">
			<p class="text-xl font-semibold text-slate-900 dark:text-slate-100">{readCard.translation || '—'}</p>
		</div>

		<!-- Tappable characters -->
		{#if readCard.language === 'zh' && hasChinese(readCard.word)}
			<div class="mb-6 flex flex-wrap justify-center gap-1">
				{#each splitChineseChars(readCard.word) as ch}
					{#if isChinese(ch)}
						<a
							href="/character/{encodeURIComponent(ch)}"
							class="chinese-char rounded-lg bg-primary/5 px-2 py-1 text-xl text-primary transition-colors hover:bg-primary/10"
						>
							{ch}
						</a>
					{:else}
						<span class="px-1 text-xl text-slate-400">{ch}</span>
					{/if}
				{/each}
			</div>
		{/if}

		<button
			onclick={nextReadCard}
			class="h-14 w-full max-w-md rounded-xl bg-primary text-lg font-bold text-white transition-all hover:opacity-90 active:scale-[0.98]"
		>
			{readIndex >= readCards.length - 1 ? 'Fertig' : 'Weiter'} &rarr;
		</button>
		<p class="mt-3 hidden text-center text-[10px] font-medium uppercase tracking-wider text-slate-400 sm:block">
			Enter oder &rarr;
		</p>
	</div>
{:else if phase === 'complete'}
	<div class="flex flex-col items-center pt-20">
		<div
			class="flex size-16 items-center justify-center rounded-full bg-primary-light text-primary"
		>
			<CheckCircle class="text-[32px]" />
		</div>
		{#if readingDone}
			<p class="mt-4 text-2xl font-bold text-slate-900 dark:text-slate-100">{readCount} neue W&ouml;rter gelesen</p>
			{#if remainingUnread > 0}
				<p class="mt-1 text-sm font-medium text-primary">
					Noch {remainingUnread} neue W&ouml;rter
				</p>
			{:else}
				<p class="mt-2 text-sm text-slate-500 dark:text-slate-400">Bereit zum &Uuml;ben!</p>
			{/if}
			<div class="mt-8 flex gap-3">
				{#if remainingUnread > 0}
					<button
						onclick={() => { readingDone = false; startReading(activeFilter, filterLabel); }}
						class="rounded-lg bg-primary px-8 py-3 font-semibold text-white shadow-md shadow-primary/20 transition-all hover:bg-primary/90"
					>
						Weiter lesen &rarr;
					</button>
				{/if}
				<button
					onclick={() => { readingDone = false; startDrill(activeFilter, filterLabel); }}
					class="rounded-lg {remainingUnread > 0 ? 'border border-slate-200 dark:border-white/10 text-slate-600 dark:text-slate-300 hover:bg-slate-50 dark:hover:bg-white/5' : 'bg-primary text-white shadow-md shadow-primary/20 hover:bg-primary/90'} px-8 py-3 font-semibold transition-all"
				>
					Jetzt &uuml;ben
				</button>
				<button
					onclick={() => { readingDone = false; clearSession(); buildSources(); phase = 'picking'; }}
					class="rounded-lg border border-slate-200 dark:border-white/10 px-8 py-3 font-semibold text-slate-600 dark:text-slate-300 transition-all hover:bg-slate-50 dark:hover:bg-white/5"
				>
					Zur&uuml;ck
				</button>
			</div>
		{:else}
			<p class="mt-4 text-2xl font-bold text-slate-900 dark:text-slate-100">Sitzung abgeschlossen</p>
			<p class="mt-2 text-sm text-slate-500 dark:text-slate-400">{reviewed} Karten gelernt</p>
			{#if remainingDue > 0}
				<p class="mt-1 text-sm font-medium text-primary">
					Noch {remainingDue} Karten f&auml;llig
				</p>
			{:else if upcomingCount > 0}
				<p class="mt-1 text-sm font-medium text-slate-500 dark:text-slate-400">
					Karten f&uuml;r morgen verf&uuml;gbar
				</p>
			{/if}
			<div class="mt-8 flex flex-wrap justify-center gap-3">
				{#if remainingDue > 0}
					<button
						onclick={() => startDrill(activeFilter, filterLabel)}
						class="rounded-lg bg-primary px-8 py-3 font-semibold text-white shadow-md shadow-primary/20 transition-all hover:bg-primary/90"
					>
						Weiter &rarr;
					</button>
				{:else if upcomingCount > 0}
					<button
						onclick={startUpcoming}
						class="rounded-lg bg-primary px-8 py-3 font-semibold text-white shadow-md shadow-primary/20 transition-all hover:bg-primary/90"
					>
						<span class="inline-flex items-center gap-2">
							<FastForward class="text-lg" />
							Vorziehen
						</span>
					</button>
				{/if}
				<button
					onclick={() => { clearSession(); buildSources(); phase = 'picking'; }}
					class="rounded-lg {remainingDue > 0 || upcomingCount > 0 ? 'border border-slate-200 dark:border-white/10 text-slate-600 dark:text-slate-300 hover:bg-slate-50 dark:hover:bg-white/5' : 'bg-primary text-white shadow-md shadow-primary/20 hover:bg-primary/90'} px-8 py-3 font-semibold transition-all"
				>
					{remainingDue > 0 || upcomingCount > 0 ? 'Zur Auswahl' : 'Weiter üben'}
				</button>
				<a
					href="/home"
					class="rounded-lg border border-slate-200 dark:border-white/10 px-8 py-3 font-semibold text-slate-600 dark:text-slate-300 transition-all hover:bg-slate-50 dark:hover:bg-white/5"
				>
					Zur&uuml;ck
				</a>
			</div>
		{/if}
	</div>
{:else if card}
	<!-- Close button -->
	<div class="mt-2 flex justify-end">
		<button
			onclick={() => { clearSession(); buildSources(); phase = 'picking'; }}
			class="flex items-center gap-1 rounded-full p-2 text-slate-400 transition-colors hover:bg-slate-100 hover:text-slate-600 dark:hover:bg-white/10 dark:hover:text-slate-300"
			title="Sitzung beenden"
		>
			<Close class="text-xl" />
		</button>
	</div>
	<!-- Progress counter -->
	<div class="mb-8 text-center">
		{#if isPeeking}
			<p class="mb-1 text-xs font-bold uppercase tracking-wider text-slate-400">Vorherige Karte</p>
		{:else if filterLabel}
			<p class="mb-1 text-xs font-bold uppercase tracking-wider text-primary">{filterLabel}</p>
		{/if}
		<div class="flex items-center justify-center gap-3">
			{#if peekCard && !isPeeking && phase === 'question'}
				<button
					onclick={goBack}
					class="flex items-center justify-center rounded-full p-1 text-slate-400 transition-colors hover:bg-slate-100 hover:text-slate-600 dark:hover:bg-white/10 dark:hover:text-slate-300"
					title="Vorherige Karte (←)"
				>
					<ArrowBack class="text-xl" />
				</button>
			{/if}
			<p class="text-lg font-bold text-slate-900 dark:text-slate-100">{isPeeking ? '' : `${index + 1} / ${total}`}</p>
		</div>
	</div>

	<!-- Card -->
	<div class="flex flex-col items-center justify-center">
		<div class="mb-8 text-center">
			{#if questionIsChinese}
				<h1 class="chinese-char mb-2 text-6xl font-bold tracking-tight text-slate-900 dark:text-slate-100">
					{questionText}
				</h1>
				{#if direction === 'zh-de' && card.pinyin}
					<div class="flex items-center justify-center gap-3">
						<p class="text-lg font-medium text-primary">{card.pinyin}</p>
						<button
							onclick={() => speak(card.word, card.language)}
							class="flex items-center justify-center rounded-full bg-primary/10 p-2 text-primary transition-colors hover:bg-primary/20"
						>
							<VolumeUp class="text-xl" />
						</button>
					</div>
				{:else}
					<button
						onclick={() => speak(card.word, card.language)}
						class="mt-2 flex items-center justify-center rounded-full bg-primary/10 p-2 text-primary transition-colors hover:bg-primary/20"
					>
						<VolumeUp class="text-xl" />
					</button>
				{/if}
			{:else if questionIsArabic}
				<h1 dir="rtl" class="mb-2 text-5xl font-bold leading-relaxed tracking-tight text-slate-900 dark:text-slate-100">
					{questionText}
				</h1>
				<button
					onclick={() => speak(card.word, card.language)}
					class="mt-2 flex items-center justify-center rounded-full bg-primary/10 p-2 text-primary transition-colors hover:bg-primary/20"
				>
					<VolumeUp class="text-xl" />
				</button>
			{:else}
				<div class="flex items-center justify-center gap-3">
					<h1 class="{questionText.length > 60 ? 'text-lg' : questionText.length > 30 ? 'text-2xl' : 'text-4xl'} font-bold tracking-tight text-slate-900 dark:text-slate-100">{questionText}</h1>
					<button
						onclick={() => speak(card.word, card.language)}
						class="flex items-center justify-center rounded-full bg-primary/10 p-2 text-primary transition-colors hover:bg-primary/20"
					>
						<VolumeUp class="text-xl" />
					</button>
				</div>
			{/if}
		</div>

		<!-- Input area -->
		<div class="w-full max-w-md space-y-4">
			{#if phase === 'question'}
				{#if selfAssessMode}
					<!-- Self-assessment: tap to reveal, no typing -->
					<button
						onclick={reveal}
						class="h-14 w-full rounded-xl bg-primary text-lg font-bold text-white transition-all hover:opacity-90 active:scale-[0.98]"
					>
						Aufdecken
					</button>
					<p class="text-center text-[10px] font-medium uppercase tracking-wider text-slate-400">
						Enter oder Leertaste
					</p>
				{:else}
					<div class="relative">
						<input
							type="text"
							bind:value={input}
							placeholder="{direction === 'zh-pinyin' ? 'Pinyin eingeben...' : direction === 'de-zh' ? 'Chinesisch eingeben...' : 'Übersetzung eingeben...'}"
							class="h-14 w-full rounded-xl border-2 border-primary bg-primary-light text-center text-lg text-slate-900 dark:text-slate-100 placeholder-primary/60 outline-none focus:ring-2 focus:ring-primary"
						/>
					</div>
					<button
						onclick={reveal}
						class="h-14 w-full rounded-xl bg-primary text-lg font-bold text-white transition-all hover:opacity-90 active:scale-[0.98]"
					>
						Pr&uuml;fen
					</button>
				{/if}
			{:else}
				<!-- Answer revealed -->
				{#if selfAssessMode}
					<!-- Self-assessment: show definition in readable format -->
					<div class="w-full rounded-xl border-2 border-primary bg-white p-5 dark:bg-white/5">
						<p class="text-[11px] font-bold uppercase tracking-wider text-primary mb-2">Definition</p>
						<p class="text-base leading-relaxed text-slate-700 dark:text-slate-200">
							{expectedAnswer || '\u2014'}
						</p>
					</div>
					<p class="text-center text-xs text-slate-400 dark:text-slate-500">
						Wusstest du es? Bewerte dich selbst.
					</p>
				{:else}
					<div
						class="flex w-full items-stretch overflow-hidden rounded-xl border-2 {answerCorrect === true
							? 'border-green-500'
							: answerCorrect === false
								? 'border-red-400'
								: 'border-primary'} bg-white dark:bg-white/5"
					>
						<div
							class="flex-1 p-4 text-xl font-semibold {answerCorrect === true
								? 'text-green-600 dark:text-green-400'
								: answerCorrect === false
									? 'text-red-600 dark:text-red-400'
									: 'text-primary dark:text-accent'}"
						>
							{expectedAnswer || '\u2014'}
						</div>
						<div
							class="flex items-center {answerCorrect === true
								? 'bg-green-50 dark:bg-green-500/15'
								: answerCorrect === false
									? 'bg-red-50 dark:bg-red-500/15'
									: 'bg-primary/5 dark:bg-primary/20'} px-4"
						>
							<Icon
								name={answerCorrect === true ? 'check_circle' : answerCorrect === false ? 'cancel' : 'check_circle'}
								class="text-3xl font-bold {answerCorrect === true
									? 'text-green-500 dark:text-green-400'
									: answerCorrect === false
										? 'text-red-500 dark:text-red-400'
										: 'text-primary dark:text-accent'}"
							/>
						</div>
					</div>

					{#if input}
						<p
							class="text-center text-sm {answerCorrect === true
								? 'text-green-600 dark:text-green-400'
								: answerCorrect === false
									? 'text-red-500 dark:text-red-400'
									: 'text-slate-400 dark:text-slate-500'}"
						>
							Deine Antwort: <span class="font-medium">{input}</span>
							{#if answerCorrect === true}
								&mdash; Richtig!
							{:else if answerCorrect === false}
								&mdash; Falsch
							{/if}
						</p>
					{/if}
				{/if}

				<!-- Tappable characters (for Chinese answers) -->
				{#if card.language === 'zh' && direction !== 'zh-pinyin' && hasChinese(card.word)}
					<div class="flex flex-wrap justify-center gap-1">
						{#each splitChineseChars(card.word) as ch}
							{#if isChinese(ch)}
								<a
									href="/character/{encodeURIComponent(ch)}"
									class="chinese-char rounded-lg bg-primary/5 px-2 py-1 text-xl text-primary transition-colors hover:bg-primary/10"
								>
									{ch}
								</a>
							{:else}
								<span class="px-1 text-xl text-slate-400">{ch}</span>
							{/if}
						{/each}
					</div>
				{/if}

				{#if isPeeking}
					<!-- Peek mode: read-only, dismiss to continue -->
					<button
						onclick={dismissPeek}
						class="mt-6 h-14 w-full rounded-xl bg-primary text-lg font-bold text-white transition-all hover:opacity-90 active:scale-[0.98]"
					>
						Weiter &rarr;
					</button>
					<p
						class="mt-3 hidden text-center text-[10px] font-medium uppercase tracking-wider text-slate-400 sm:block"
					>
						Enter oder &rarr;
					</p>
				{:else}
					<!-- Rating buttons -->
					<div class="mt-6 grid w-full grid-cols-4 gap-3">
						<button
							onclick={() => rate(1)}
							class="flex flex-col items-center justify-center rounded-xl border border-red-200 bg-red-50 py-4 transition-all hover:brightness-95 dark:border-red-800 dark:bg-red-950"
						>
							<span class="text-sm font-bold uppercase tracking-tighter text-red-700"
								>Nochmal</span
							>
							<span class="mt-1 text-xs text-red-500"
								>{formatInterval(card.intervals.again)}</span
							>
						</button>
						<button
							onclick={() => rate(2)}
							class="flex flex-col items-center justify-center rounded-xl border border-amber-200 bg-amber-50 py-4 transition-all hover:brightness-95 dark:border-amber-800 dark:bg-amber-950"
						>
							<span class="text-sm font-bold uppercase tracking-tighter text-amber-700"
								>Schwer</span
							>
							<span class="mt-1 text-xs text-amber-500"
								>{formatInterval(card.intervals.hard)}</span
							>
						</button>
						<button
							onclick={() => rate(3)}
							class="flex flex-col items-center justify-center rounded-xl border border-green-200 bg-green-50 py-4 transition-all hover:brightness-95 dark:border-green-800 dark:bg-green-950"
						>
							<span class="text-sm font-bold uppercase tracking-tighter text-green-700">Gut</span>
							<span class="mt-1 text-xs text-green-500"
								>{formatInterval(card.intervals.good)}</span
							>
						</button>
						<button
							onclick={() => rate(4)}
							class="flex flex-col items-center justify-center rounded-xl border-2 border-primary bg-white py-4 transition-all hover:bg-primary/5 dark:bg-white/5"
						>
							<span class="text-sm font-bold uppercase tracking-tighter text-primary"
								>Einfach</span
							>
							<span class="mt-1 text-xs text-primary/70"
								>{formatInterval(card.intervals.easy)}</span
							>
						</button>
					</div>
					<div class="mt-3 flex items-center justify-center gap-4">
						<p
							class="hidden text-[10px] font-medium uppercase tracking-wider text-slate-400 sm:block"
						>
							Tastatur: 1-4
						</p>
						{#if card.source_type === 'lexicon'}
							<button
								onclick={handleRemoveCard}
								class="flex items-center gap-1 text-[10px] font-medium uppercase tracking-wider text-slate-400 transition-colors hover:text-red-500"
								title="Aus Lexikon entfernen"
							>
								<Delete class="text-[14px]" />
								Entfernen
							</button>
						{/if}
					</div>
				{/if}
			{/if}
		</div>
	</div>
{/if}
