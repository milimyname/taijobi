import { json } from '@sveltejs/kit';
import codec from 'kamiya-codec';

function classifyWord(word: string) {
	// Implement logic to determine if the word is a verb or an adjective
	// This is a simplified example; actual implementation may require a more sophisticated approach
	if (word.endsWith('る') || word.endsWith('う') || word.endsWith('く') || word.endsWith('ます')) {
		return 'verb';
	} else if (word.endsWith('い') || word.endsWith('ない')) {
		return 'adjective';
	}
	return 'unknown'; // Fallback case
}

/** @type {import('./$types').RequestHandler} */
export async function POST({ request }) {
	const { word } = await request.json();

	// Check if the word is a verb or adjective
	const classification = classifyWord(word);

	if (classification === 'unknown') {
		return json({
			error: 'The word is not a verb or adjective'
		});
	}

	return json({
		conjugated: {
			taiNegative: codec.conjugateAuxiliaries(word, ['Tai'], 'Negative'),
			naiTe: codec.conjugateAuxiliaries(word, ['Nai'], 'Te'),
			te: codec.conjugateAuxiliaries(word, [], 'Te')
		}
	});
}
