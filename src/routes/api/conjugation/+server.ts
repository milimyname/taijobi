import { classifyWord } from '$lib/utils/flashcard';
import { conjugateVerb, conjugateAdjective } from './common';
import { json } from '@sveltejs/kit';

export async function POST({ request }) {
	const { word } = await request.json();

	if (!word) return json({ error: 'No input term provided' });

	const wordType = classifyWord(word);

	switch (wordType) {
		case 'verb': {
			return json(await conjugateVerb(word));
		}
		case 'adjective':
			return json(await conjugateAdjective(word));
		default:
			return json({ error: 'The word is not a verb or adjective or cannot be conjugated.' });
	}
}
