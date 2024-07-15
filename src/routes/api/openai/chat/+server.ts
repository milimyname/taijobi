import { env } from '$env/dynamic/private';
import { createOpenAI } from '@ai-sdk/openai';
import { streamText } from 'ai';
import { tool } from 'ai';
import { isRomaji } from 'wanakana';
import { z } from 'zod';

const openai = createOpenAI({
	apiKey: env.OPENAI_API_KEY ?? '',
});

export const POST = async ({ request, locals }) => {
	if (!locals.pb.authStore.isValid) return new Response('Unauthorized', { status: 401 });

	const { messages } = await request.json();

	const result = await streamText({
		model: openai('gpt-3.5-turbo'),
		messages,
		tools: {
			new_flashcard: tool({
				description: 'Create a new flashcard',
				parameters: z.object({
					name: z.string(),
					translation: z.string(),
					type: z.enum(['word', 'phrase', 'kanji']),
					partOfSpeech: z.enum(['verb', 'adjective', 'unknown']),
					romanji: z.string(),
				}),
				execute: async ({ name, translation, type, partOfSpeech, romanji }) => {
					const flashcardName = isRomaji(name) ? translation : name;
					const meaning = isRomaji(name) ? name : translation;

					// Create a flashcard if the search is a kanji
					let flashcard = await locals.pb.collection('flashcard').create({
						name: flashcardName,
						meaning: meaning.includes(';') ? meaning.split(';').join(',') : meaning,
						type,
						romanji,
						partOfSpeech,
					});

					const newSearch = await locals.pb.collection('searches').create({
						flashcard: flashcard.id,
						user: locals.pb.authStore.model?.id,
						searchQuery: name,
					});

					flashcard = await locals.pb.collection('flashcard').update(flashcard.id, {
						'searches+': newSearch.id,
					});

					return flashcard;
				},
			}),
		},
		system: `You are a japanese teacher who is teaching a student how to speak japanese.
		Be a nice teacher and help the student learn japanese if they ask for help. For grammatical explanations, don't ask to save it as a flashcard.
		Ask the student after translating a word/sentence to japanese to save it as a flashcard.
		if the student wants to save a word/sentence as a flashcard, use the tool "new_flashcard" to create a new flashcard.
		`,
	});

	return result.toAIStreamResponse();
};
