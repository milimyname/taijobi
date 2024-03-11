import { json } from '@sveltejs/kit';

function conjugateVerb(verb: string) {
	// Convert to dictionary form (assumes verb is given in polite non-past, e.g., 食べます -> 食べる)
	let dictionaryForm;
	if (verb.endsWith('ます')) {
		dictionaryForm = verb.slice(0, -2) + 'る';
	} else {
		dictionaryForm = verb; // assuming the verb is already in dictionary form
	}

	// Determine the verb group
	let group;
	if (dictionaryForm === '来る') {
		group = 3; // 来る is an irregular verb
	} else if (dictionaryForm === 'する') {
		group = 4; // する is an irregular verb
	} else if (
		dictionaryForm.endsWith('る') &&
		(dictionaryForm.includes('いる') || dictionaryForm.includes('える'))
	) {
		group = 2; // Group 2 verbs
	} else {
		group = 1; // Group 1 verbs
	}

	const stem = dictionaryForm.slice(0, -1); // Remove last character to get the stem
	let teForm, taForm, naiForm, potentialForm, imperativeForm;

	// Conjugate based on the group
	switch (group) {
		case 1: {
			// Group 1: う-verbs
			const lastKana = dictionaryForm.slice(-1);
			const kanaMap: { [key: string]: string } = {
				う: 'って',
				つ: 'って',
				る: 'って',
				ぶ: 'んで',
				む: 'んで',
				ぬ: 'んで',
				く: 'いて',
				ぐ: 'いで',
				す: 'して'
			};
			const teEnding = kanaMap[lastKana] || 'って';
			teForm = `${stem}${teEnding}`;
			taForm = `${stem}${teEnding.slice(0, -1)}た`;
			naiForm = `${stem}ない`;
			potentialForm = `${stem.slice(0, -1)}える`;
			imperativeForm = `${stem}ろ`;
			break;
		}
		case 2:
			// Group 2: る-verbs
			teForm = `${stem}て`;
			taForm = `${stem}た`;
			naiForm = `${stem}ない`;
			potentialForm = `${stem}られる`;
			imperativeForm = `${stem}ろ`;
			break;
		case 3:
			// Irregular: 来る (kuru)
			teForm = 'きて';
			taForm = 'きた';
			naiForm = 'こない';
			potentialForm = 'こられる';
			imperativeForm = 'こい';
			break;
		case 4:
			// Irregular: する (suru)
			teForm = 'して';
			taForm = 'した';
			naiForm = 'しない';
			potentialForm = 'できる';
			imperativeForm = 'しろ';
			break;
	}

	// Define conjugations
	return {
		Dictionary: dictionaryForm,
		Te: teForm,
		Ta: taForm,
		Nai: naiForm,
		Masu: `${stem}ます`,
		Masen: `${stem}ません`,
		Mashita: `${stem}ました`,
		'Masen Deshita': `${stem}ませんでした`,
		Potential: potentialForm,
		Imperative: imperativeForm
	};
}

function conjugateAdjective(adjective: string) {
	let root: string;
	let teForm: string, pastForm: string, negativeForm: string, pastNegativeForm: string;

	if (adjective.endsWith('い') && !adjective.endsWith('ない')) {
		root = adjective.slice(0, -1);

		teForm = `${root}くて`;
		pastForm = `${root}かった`;
		negativeForm = `${root}くない`;
		pastNegativeForm = `${root}くなかった`;
	} else {
		root = adjective.slice(0, -1);

		teForm = `${root}で`;
		pastForm = `${root}だった`;
		negativeForm = `${root}ではない`;
		pastNegativeForm = `${root}ではなかった`;
	}

	return {
		teForm,
		pastForm,
		negativeForm,
		pastNegativeForm
	};
}

function classifyWord(word: string) {
	// More nuanced logic to determine if the word is a verb or an adjective

	// Check for verbs
	// Verbs in plain form can end with any character in the 'う' row of the kana table
	const verbEndings = ['う', 'く', 'す', 'つ', 'ぬ', 'ふ', 'む', 'る', 'ぐ', 'ぶ'];
	const masuEnding = 'ます';
	const teEnding = 'て';
	const taEnding = 'た';

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
		word.endsWith(taEnding)
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

/** @type {import('./$types').RequestHandler} */
export async function POST({ request }) {
	const { word } = await request.json();

	const wordType = classifyWord(word);

	switch (wordType) {
		case 'verb':
			return json(conjugateVerb(word));
		case 'adjective':
			return json(conjugateAdjective(word + (word.endsWith('な') ? '' : 'な'))); // Ensure 'な' is appended for na-adjectives
		default:
			return json({ error: 'The word is not a verb or adjective or cannot be conjugated.' });
	}
}
