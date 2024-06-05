import { kuroshiro } from '$lib/server/kuroshiro.js';
import { json } from '@sveltejs/kit';
import { isKanji } from 'wanakana';
import { classifyWord, conjugateAdjective, conjugateVerb } from './common.js';

export async function POST({ request }) {
	const { word } = await request.json();

	if (!word) return json({ message: 'No input term provided' });

	const wordType = classifyWord(word);

	// Convert to hiragana if it's kanji
	if (word.split('').some((char: string) => isKanji(char))) {
		const convertedToHiragana = await kuroshiro.convert(word, { to: 'hiragana' });

		switch (wordType) {
			case 'verb':
				return json(await conjugateVerb(convertedToHiragana, word));
			case 'adjective':
				return json(conjugateAdjective(word + (word.endsWith('な') ? '' : 'な'))); // Ensure 'な' is appended for na-adjectives
			default:
				return json({ error: 'The word is not a verb or adjective or cannot be conjugated.' });
		}
	}

	switch (wordType) {
		case 'verb':
			return json(await conjugateVerb(word));
		case 'adjective':
			return json(conjugateAdjective(word + (word.endsWith('な') ? '' : 'な'))); // Ensure 'な' is appended for na-adjectives
		default:
			return json({ error: 'The word is not a verb or adjective or cannot be conjugated.' });
	}
}
