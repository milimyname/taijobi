/**
 * Lazy in-memory pinyin index for fuzzy search.
 * Built on first use; invalidated when data.bump() count changes.
 */
import { getLexicon, getPacks, getLessons, getVocabulary } from './wasm';
import { data } from './data.svelte';

// Diacritic → base vowel map. Covers Mandarin tone marks (ā á ǎ à) and ü tones.
const DIACRITIC_MAP: Record<string, string> = {
	ā: 'a',
	á: 'a',
	ǎ: 'a',
	à: 'a',
	ē: 'e',
	é: 'e',
	ě: 'e',
	è: 'e',
	ī: 'i',
	í: 'i',
	ǐ: 'i',
	ì: 'i',
	ō: 'o',
	ó: 'o',
	ǒ: 'o',
	ò: 'o',
	ū: 'u',
	ú: 'u',
	ǔ: 'u',
	ù: 'u',
	ǖ: 'u',
	ǘ: 'u',
	ǚ: 'u',
	ǜ: 'u',
	ü: 'u'
};

export function normalizePinyin(s: string): string {
	if (!s) return '';
	let out = '';
	for (const ch of s.toLowerCase()) {
		if (ch === ' ' || ch === "'" || (ch >= '0' && ch <= '9')) continue;
		out += DIACRITIC_MAP[ch] ?? ch;
	}
	return out;
}

export interface PinyinHit {
	id: string;
	word: string;
	pinyin: string;
	translation: string | null;
}

interface IndexEntry {
	id: string;
	word: string;
	pinyin: string;
	pinyinNorm: string;
	translation: string | null;
}

class SearchIndex {
	private entries: IndexEntry[] = [];
	private builtVersion = -1;
	private building: Promise<void> | null = null;

	async ensureBuilt(): Promise<void> {
		const v = data.version();
		if (this.builtVersion === v) return;
		if (this.building) return this.building;
		this.building = (async () => {
			this.build();
			this.builtVersion = v;
			this.building = null;
		})();
		return this.building;
	}

	private build(): void {
		const seen = new Set<string>();
		const out: IndexEntry[] = [];
		for (const lex of getLexicon()) {
			if (!lex.pinyin) continue;
			seen.add(lex.id);
			out.push({
				id: lex.id,
				word: lex.word,
				pinyin: lex.pinyin,
				pinyinNorm: normalizePinyin(lex.pinyin),
				translation: lex.translation
			});
		}
		try {
			for (const pack of getPacks()) {
				for (const lesson of getLessons(pack.id)) {
					for (const vocab of getVocabulary(lesson.id)) {
						if (!vocab.pinyin || seen.has(vocab.id)) continue;
						seen.add(vocab.id);
						out.push({
							id: vocab.id,
							word: vocab.word,
							pinyin: vocab.pinyin,
							pinyinNorm: normalizePinyin(vocab.pinyin),
							translation: vocab.translation
						});
					}
				}
			}
		} catch (e) {
			console.error('[searchIndex] build failed', e);
		}
		this.entries = out;
	}

	invalidate(): void {
		this.builtVersion = -1;
		this.entries = [];
	}

	async fuzzyPinyin(query: string, limit = 10): Promise<PinyinHit[]> {
		await this.ensureBuilt();
		const q = normalizePinyin(query);
		if (!q) return [];
		const hits: PinyinHit[] = [];
		for (const e of this.entries) {
			if (e.pinyinNorm.includes(q)) {
				hits.push({ id: e.id, word: e.word, pinyin: e.pinyin, translation: e.translation });
				if (hits.length >= limit) break;
			}
		}
		return hits;
	}
}

export const searchIndex = new SearchIndex();
