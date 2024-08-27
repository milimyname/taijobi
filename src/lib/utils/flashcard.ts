export function getFlashcardType(type: string) {
	let t = 'phrase';
	switch (type) {
		case 'kanji':
			t = 'kanji';
			break;
		case 'word':
			t = 'word';
			break;
	}
	return t;
}

export function getFlashcardPartOfSpeech(partOfSpeech: string) {
	let p = 'unknown';
	switch (partOfSpeech) {
		case 'verb':
			p = 'verb';
			break;
		case 'adjective':
			p = 'adjective';
			break;
	}
	return p;
}

export function classifyWord(word: string): 'verb' | 'adjective' | 'noun' | 'unknown' {
	// Helper function to check if a word ends with any of the given endings
	const endsWithAny = (word: string, endings: string[]) =>
		endings.some((ending) => word.endsWith(ending));

	// Verb patterns
	const verbEndings = ['う', 'く', 'す', 'つ', 'ぬ', 'ふ', 'む', 'る', 'ぐ', 'ぶ'];
	const verbForms = ['ます', 'て', 'た', 'ない', 'なかった', 'れる', 'られる', 'せる', 'させる'];
	const ichidanVerbs = [
		'える',
		'いる',
		'きる',
		'ぎる',
		'しる',
		'じる',
		'ちる',
		'にる',
		'ひる',
		'びる',
		'みる',
		'りる',
	];

	// Adjective patterns
	const iAdjEnding = 'い';
	const naAdjEndings = ['な', 'に'];
	const commonNaAdj = ['きれい', 'ゆうめい', 'しずか', 'たいせつ', 'じゆう', 'けんこう'];

	// Noun patterns (expanded)
	const nounEndings = ['さ', 'み', 'け', 'ち', 'つ', 'り', 'しさ', 'さま', 'どの', 'かた'];

	// Check for verbs
	if (
		endsWithAny(word, verbEndings) ||
		endsWithAny(word, verbForms) ||
		(word.endsWith('る') && endsWithAny(word.slice(0, -1), ichidanVerbs))
	) {
		return 'verb';
	}

	// Check for i-adjectives
	if (word.endsWith(iAdjEnding) && !['という', 'ない', 'らしい', 'っぽい'].includes(word)) {
		return 'adjective';
	}

	// Check for na-adjectives
	if (endsWithAny(word, naAdjEndings) || commonNaAdj.includes(word)) {
		return 'adjective';
	}

	// Check for nouns (expanded check)
	if (
		endsWithAny(word, nounEndings) ||
		(word.length > 1 && ['人', '物', '所'].includes(word.slice(-1)))
	) {
		return 'noun';
	}

	// If no patterns match, return unknown
	return 'unknown';
}
