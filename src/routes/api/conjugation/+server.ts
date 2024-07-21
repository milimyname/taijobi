import { classifyWord } from '$lib/utils/flashcard';
import { conjugateVerb, getDictionaryForm, conjugateAdjective } from './common';
import { json } from '@sveltejs/kit';

export async function POST({ request }) {
	const { word } = await request.json();

	if (!word) return json({ error: 'No input term provided' });

	const wordType = classifyWord(word);

	switch (wordType) {
		case 'verb': {
			const conjuctive = getDictionaryForm(word);
			return json(await conjugateVerb(conjuctive));
		}
		case 'adjective':
			return json(await conjugateAdjective(word));
		default:
			return json({ error: 'The word is not a verb or adjective or cannot be conjugated.' });
	}
}
