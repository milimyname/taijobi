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

export function classifyWord(word: string) {
	// More nuanced logic to determine if the word is a verb or an adjective

	// Check for verbs
	// Verbs in plain form can end with any character in the 'う' row of the kana table
	const verbEndings = ['う', 'く', 'す', 'つ', 'ぬ', 'ふ', 'む', 'る', 'ぐ', 'ぶ'];
	const masuEnding = 'ます';
	const teEnding = 'て';
	const taEnding = 'た';
	const extendedVerbEndings = [
		'いる',
		'える',
		'れる',
		'せる',
		'てる',
		'ける',
		'ねる',
		'べる',
		'める',
		'るる',
	];

	// Check for adjectives
	// i-adjectives end in 'い', but not all words ending in 'い' are adjectives
	const iAdjectiveEnding = 'い';
	const naAdjectiveHint = 'な'; // This is just a hint, not definitive

	const lastCharacter = word.slice(-1);
	const secondLastCharacter = word.slice(-2, -1);

	if (
		verbEndings.includes(lastCharacter) ||
		word.endsWith(masuEnding) ||
		word.endsWith(teEnding) ||
		word.endsWith(taEnding) ||
		extendedVerbEndings.some((ending) => word.endsWith(ending))
	) {
		return 'verb';
	} else if (lastCharacter === iAdjectiveEnding && secondLastCharacter !== naAdjectiveHint) {
		// Check if it's likely an i-adjective
		// This is a simplistic check; in reality, some nouns end in 'い'
		return 'adjective';
	} else if (
		word.endsWith(naAdjectiveHint) ||
		(secondLastCharacter === naAdjectiveHint && lastCharacter === iAdjectiveEnding)
	) {
		// Words that end in 'な' or 'ない' could be na-adjectives
		// However, this can also include nouns followed by the particle 'な'
		return 'adjective';
	}

	return 'unknown'; // Fallback case
}
