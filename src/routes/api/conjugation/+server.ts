import { json } from '@sveltejs/kit';
import { classifyWord, conjugateVerb, getConjuctiveForm, conjugateAdjective } from './common';

export async function POST({ request }) {
	const { word } = await request.json();

	if (!word) return json({ error: 'No input term provided' });

	const wordType = classifyWord(word);

	switch (wordType) {
		case 'verb': {
			const conjuctive = getConjuctiveForm(word);
			return json(await conjugateVerb(conjuctive));
		}
		case 'adjective':
			return json(await conjugateAdjective(word));
		default:
			return json({ error: 'The word is not a verb or adjective or cannot be conjugated.' });
	}
}
