import { kuroshiro } from '$lib/server/kuroshiro';
import { openai } from '$lib/server/openai';
import { openaiSchema } from '$lib/utils/zodSchema';
import { json } from '@sveltejs/kit';

interface Found {
	name: string;
	meaning: string;
	partOfspeech?: string;
	romanji?: string;
	furigana?: string;
}

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
					`,
			},
			{
				role: 'user',
				content: input,
			},
		];

		// Ask OpenAI for a streaming chat completion given the prompt
		const completion = await openai.chat.completions.create({
			model: 'gpt-3.5-turbo',
			messages,
			response_format: { type: 'json_object' },
			temperature: 1,
		});

		// If there's no response, return an empty array
		if (!completion.choices[0].message.content) return json({ exampleSentences: [] });

		let parsedData = [JSON.parse(completion.choices[0].message.content)];

		if (parsedData[0]?.sentences) parsedData = parsedData[0].sentences;

		const examples = await Promise.all(
			parsedData.map(async (message) => {
				const furigana = await kuroshiro.convert(message.kanji, {
					to: 'hiragana',
					mode: 'furigana',
				});

				return {
					...message,
					furigana,
				};
			}),
		);

		// Return the response from OpenAI
		return json(examples);
	}

	if (type === 'find') {
		const messages = [
			{
				role: 'system',
				content: `You are a Japanese teacher. Return a json object with the meaning and part of speech.
						Type can be either 'word', 'kanji' or 'phrase'. Part of speech can be either 'verb', 'adjective' or 'unknown'. 
						If user's input is a typo, suggest a similar word or phrase.
						Example:
						{
							"name": "走る",
							"meaning": "to run",
							"partOfspeech": "verb",
							"romanji": "hashiru",
							"furigana": "はしる",
							"type": "word",
						}

						Suggested Example:
						{
							"name": "特別",
							"meaning": "special",
							"suggested": true,
							"partOfspeech": "unknown",
							"furigana": "tokubetsu",
							"type": "phrase",
						}

						If it does not exist or does not have a meaning, return the following:
						{
							"name": "るる",
							"meaning": "Does not exist",
						}
					`,
			},
			{
				role: 'user',
				content: input,
			},
		];

		// Ask OpenAI for a streaming chat completion given the prompt
		const completion = await openai.chat.completions.create({
			model: 'gpt-3.5-turbo',
			messages,
			response_format: { type: 'json_object' },
			temperature: 0.6,
		});

		// If there's no response, return an empty array
		if (!completion.choices[0].message.content) return json({ found: [] });

		let found = JSON.parse(completion.choices[0].message.content) as Found;

		if (found.meaning !== 'Does not exist') {
			found = {
				...found,
				furigana: await kuroshiro.convert(found?.name, {
					to: 'hiragana',
					mode: 'furigana',
				}),
			};
		}

		// Return the response from OpenAI
		return json(found);
	}

	if (type === 'search') {
		const messages = [
			{
				role: 'system',
				content: `You are a Japanese teacher. User will provide either a word in english or in japanese.
						Translate it to Japanese or English. Return a json object with the meaning and part of speech.
						Type can be either 'word', 'kanji' or 'phrase'. Part of speech can be either 'verb', 'adjective' or 'unknown'. 
						If user's input is a typo, suggest a similar word or phrase.
						Example: 
						user's input is 走る
						{
							"name": "走る",
							"type": "word",
							"meaning": "to run",
							"partOfspeech": "verb",
							"romanji": "hashiru",
							"furigana": "はしる",
						}
						
						user's input is new word:
						{
							"name": "新しい言葉",
							"type": "phrase",
							"meaning": "new word",
							"partOfspeech": "unknown",
							"romanji": "atarashii kotoba",
							"furigana": "あたらしいことば",
						}
					`,
			},
			{
				role: 'user',
				content: input,
			},
		];

		// Ask OpenAI for a streaming chat completion given the prompt
		const completion = await openai.chat.completions.create({
			model: 'gpt-3.5-turbo',
			messages,
			response_format: { type: 'json_object' },
			temperature: 0.6,
		});

		// If there's no response, return an empty array
		if (!completion.choices[0].message.content) return json({ found: [] });

		let searched = JSON.parse(completion.choices[0].message.content) as searched;

		if (searched.meaning !== 'Does not exist') {
			searched = {
				...searched,
				furigana: await kuroshiro.convert(searched?.name, {
					to: 'hiragana',
					mode: 'furigana',
				}),
			};
		}

		// Return the response from OpenAI
		return json(searched);
	}

	if (type === 'audio') {
		const mp3 = await openai.audio.speech.create({
			model: 'tts-1',
			voice: 'nova',
			input,
		});

		const buffer = Buffer.from(await mp3.arrayBuffer());
		const base64Audio = buffer.toString('base64');

		return json({ audioData: base64Audio });
	}

	return json({ error: 'Invalid type' });
}
