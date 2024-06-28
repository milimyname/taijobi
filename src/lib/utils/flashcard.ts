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
