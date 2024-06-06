import { json } from '@sveltejs/kit';
import { kuroshiro } from '$lib/server/kuroshiro';
import { openai } from '$lib/server/openai';
import { openaiSchema } from '$lib/utils/zodSchema';

export async function POST({ request, locals }) {
	// if user is not authenticated, return 401
	if (!locals.pb.authStore.isValid) return new Response('Unauthorized', { status: 401 });

	const { input, type } = await request.json();

	// Validate the input
	const validatedData = openaiSchema.safeParse({ input, type });

	if (!validatedData.success) return json({ error: validatedData.error });

	if (type === 'text') {
		const messages = [
			{
				role: 'system',
				content: `You are a Japanese teacher. Create a sentence with given words separated by a comma.
					Please respond with a JSON object in array format with translation and sentence properties.
					Example:
						{
							"kanji": "家に着く前に電話します。",
							"english": "I will call before arriving home."
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

		const examples = await Promise.all(
			parsedData.map(async (message) => {
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

		// Return the response from OpenAI
		return json(examples);
	}

	if (type === 'audio') {
		const mp3 = await openai.audio.speech.create({
			model: 'tts-1',
			voice: 'nova',
			input
		});

		const buffer = Buffer.from(await mp3.arrayBuffer());
		const base64Audio = buffer.toString('base64');

		return json({ audioData: base64Audio });
	}

	return json({ error: 'Invalid type' });
}
