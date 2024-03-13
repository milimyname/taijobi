import OpenAI from 'openai';
import { OPENAI_API_KEY } from '$env/static/private';
import { json } from '@sveltejs/kit';
import { kuroshiro } from '$lib/server/kuroshiro';

// Create an OpenAI API client (that's edge friendly!)
const openai = new OpenAI({
	apiKey: OPENAI_API_KEY
});

export async function POST({ request, locals }) {
	// if user is not authenticated, return 401
	if (!locals.pb.authStore.isValid) return new Response('Unauthorized', { status: 401 });

	const { input } = await request.json();

	const messages = [
		{
			role: 'system',
			content: `You are a Japanese teacher. Create a sentence with given words separated by a comma.
					Please respond with a JSON object in array format with translation and sentence properties.
					Example:
						{
							"sentence": "家に着く前に電話します。",
							"meaning": "I will call before arriving home."
						}
					`
		},
		{
			role: 'user',
			content: input
		}
	];

	// Ask OpenAI for a streaming chat completion given the prompt
	const completion = await openai.chat.completions.create({
		model: 'gpt-3.5-turbo',
		messages,
		response_format: { type: 'json_object' },
		temperature: 1
	});

	// If there's no response, return an empty array
	if (!completion.choices[0].message.content) return json({ exampleSentences: [] });

	let parsedData = [JSON.parse(completion.choices[0].message.content)];

	if (parsedData[0]?.sentences) parsedData = parsedData[0].sentences;

	const proccesesMessages = await Promise.all(
		parsedData.map(async (message) => {
			const sentence = await kuroshiro.convert(message.sentence, {
				to: 'hiragana',
				mode: 'furigana'
			});

			return {
				...message,
				sentence
			};
		})
	);

	// Return the response from OpenAI
	return json({ exampleSentences: proccesesMessages });
}
