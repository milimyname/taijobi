import { convertToFurigana } from '$lib/server/kuroshiro';
import { ai } from '$lib/server/openai';
import { generateObject } from 'ai';
import { z } from 'zod';

type Prompt = {
	prompt: string;
	recordID: string;
};

export const POST = async ({ request, locals }) => {
	if (!locals.pb.authStore.isValid) return new Response('Unauthorized', { status: 401 });

	const { prompt, recordID }: Prompt = await request.json();

	if (!prompt || !recordID) return new Response('Prompt is required', { status: 400 });

	console.time('generateObject');

	const result = await generateObject({
		model: ai('gpt-4o-mini'),
		maxTokens: 16000,
		temperature: 0.7,
		schema: z.object({
			kana: z.string(),
			meaning: z.string(),
			detailed: z.array(
				z.object({
					kana: z.string(),
					meaning: z.string(),
					hiragana: z.string(),
				}),
			),
		}),
		prompt,
		system: `You are a Japanese teacher. Remove only unnecessary words, unnecessary numbers or unnecessary punctuations from the text that do not make sense but do not remove the convert Please fully translate the text into English and provide the meaning of each word in the text.
					Given text: 早く下の層に降りられるようにならないと掘るものがなくなっちゃうよ。
					Example:
							{
								"kana": "早く下の層に降りられるようにならないと掘るものがなくなっちゃうよ。",
								"meaning": "But if we can't get into the lower stratum soon, we'll be out of stuff to dig.",
								"detailed": [
									{
										"kana": "早く",	
										"meaning": "quickly",
										"hiragana": "はやく"
									},
									{
										"kana": "下",
										"meaning": "down",
										"hiragana": "した"	
									},
									{
										"kana": "層",
										"meaning": "layer",
										"hiragana": "そう",
									},
									{
										"kana": "降りられる",
										"meaning": "able to descend",
										"hiragana": "おりられる"
									},
									{
										"kana": "ならない",
										"meaning": "not become",
										"hiragana": "ならない"
									},
									{
										"kana": "掘る",
										"meaning": "dig",
										"hiragana": "ほる"
									},
									{
										"kana": "もの",
										"meaning": "stuff",
										"hiragana": "もの"
									},
									{
										"kana": "なくなっちゃうよ",
										"meaning": "run out",
										"hiragana": "なくなっちゃうよ"
									}
								]
							},

					`,
	});

	console.timeEnd('generateObject');

	// Update the record with the formatted AI data
	await locals.pb.collection('paragraphs').update(recordID, {
		formatted_ai_data: JSON.stringify({
			...result.object,
			kana: result.object.kana,
			kanaWithFurigana: await convertToFurigana(result.object.kana),
		}),
	});

	return result.toJsonResponse();
};
