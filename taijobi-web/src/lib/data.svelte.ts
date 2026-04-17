/**
 * Reactive data store over libtaijobi WASM.
 * Methods auto-invalidate when bump() is called (sync receive or local mutations).
 * Pages use: `let cards = $derived(data.dueCards())` — no void hacks.
 */
import {
	getDueCount,
	getDueCards,
	getDueCardsFiltered,
	getDueCountFiltered,
	getUpcomingCards,
	getUnreadCards,
	getUnreadCount,
	getLexicon,
	getDrillStats,
	getPacks,
	getLessons,
	getVocabulary,
	getPackProgress,
	getStats,
	getLastReviewedCard,
	isChineseDataLoaded,
	isEndictLoaded,
	isDedictLoaded,
	type Card,
	type CardSearchResult,
	type ReadCard,
	type LexiconEntry,
	type DrillStats,
	type StatsData,
	type Pack,
	type Lesson,
	type VocabEntry,
	type PackProgress
} from './wasm';

// oxlint-disable no-unused-expressions, no-unused-private-class-members -- #v read triggers Svelte reactivity
class DataStore {
	#v = $state(0);

	bump() {
		this.#v++;
	}

	version(): number {
		return this.#v;
	}

	dueCount(): number {
		this.#v;
		return getDueCount();
	}

	dueCards(limit = 50): Card[] {
		this.#v;
		return getDueCards(limit);
	}

	dueCardsFiltered(filter: string, limit = 50): Card[] {
		this.#v;
		return getDueCardsFiltered(filter, limit);
	}

	dueCountFiltered(filter: string): number {
		this.#v;
		return getDueCountFiltered(filter);
	}

	upcomingCards(filter: string, limit = 50, aheadHours = 24): Card[] {
		this.#v;
		return getUpcomingCards(filter, limit, aheadHours);
	}

	unreadCards(filter: string, limit = 50): ReadCard[] {
		this.#v;
		return getUnreadCards(filter, limit);
	}

	unreadCount(filter: string): number {
		this.#v;
		return getUnreadCount(filter);
	}

	lexicon(): LexiconEntry[] {
		this.#v;
		return getLexicon();
	}

	drillStats(): DrillStats {
		this.#v;
		return getDrillStats();
	}

	packs(): Pack[] {
		this.#v;
		return getPacks();
	}

	lessons(packId: string): Lesson[] {
		this.#v;
		return getLessons(packId);
	}

	vocabulary(lessonId: string): VocabEntry[] {
		this.#v;
		return getVocabulary(lessonId);
	}

	packProgress(packId: string): PackProgress {
		this.#v;
		return getPackProgress(packId);
	}

	stats(days: number = 30): StatsData {
		this.#v;
		return getStats(days);
	}

	lastReviewedCard(): CardSearchResult | null {
		this.#v;
		return getLastReviewedCard();
	}

	chineseDataLoaded(): boolean {
		this.#v;
		return isChineseDataLoaded();
	}

	endictLoaded(): boolean {
		this.#v;
		return isEndictLoaded();
	}

	dedictLoaded(): boolean {
		this.#v;
		return isDedictLoaded();
	}
}
// oxlint-enable no-unused-expressions, no-unused-private-class-members

export const data = new DataStore();
