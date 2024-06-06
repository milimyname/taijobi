import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { kuroshiro } from '$lib/server/kuroshiro';
import { jisho, type JishoAPIResult } from '$lib/utils/jisho';

export const POST: RequestHandler = async ({ request, fetch }) => {
	const { input } = await request.json();

	if (!input) return json({ error: 'No input term provided' });

	try {
		const data = await jisho.searchForExamples(input);

		if (!data) throw new Error('No results found');

		const examples = await Promise.all(
			data.results.slice(0, 10).map(async (message) => {
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

		if (examples.length > 0) return json(examples);

		// Check if there are no examples, call openai to get examples
		const res = await fetch('/api/openai', {
			method: 'POST',
			headers: {
				'Content-Type': 'application/json'
			},
			body: JSON.stringify({ input, type: 'text' })
		});

		if (!res.ok) return json({ error: 'No results found' });

		const newExamples = await res.json();

		return json(newExamples);
	} catch (e) {
		return json({ error: 'No results found' });
	}
};
