import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { kuroshiro } from '$lib/server/kuroshiro';
import { jisho } from '$lib/utils/jisho';

export const POST: RequestHandler = async ({ request }) => {
	const { input } = await request.json();

	if (!input) return json({ message: 'No input term provided' });

	try {
		const data = await jisho.searchForExamples(input);

		if (!data) return json({ message: 'No results found' });

		const examples = await Promise.all(
			data.results.slice(0, 5).map(async (message) => {
				const furigana = await kuroshiro.convert(message.kanji, {
					to: 'hiragana',
					mode: 'furigana'
				});

				return {
					...message,
					furigana
				};
			})
		);

		return json(examples);
	} catch (e) {
		return json({ message: 'No results found' });
	}
};
