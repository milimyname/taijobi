import { ai } from '$lib/server/openai';
import { streamText } from 'ai';
import { tool } from 'ai';
import { isRomaji } from 'wanakana';
import { z } from 'zod';

export const POST = async ({ request, locals }) => {
	if (!locals.pb.authStore.isValid) return new Response('Unauthorized', { status: 401 });

	const { messages } = await request.json();

	if (!messages) return new Response('Messages are required', { status: 400 });

	const result = await streamText({
		model: ai('gpt-4o-mini'),
		maxTokens: 16000,
		temperature: 0.7,
		messages,
		tools: {
			new_flashcard: tool({
				description: 'Create a new flashcard',
				parameters: z.object({
					name: z.string(),
					translation: z.string(),
					type: z.enum(['word', 'phrase', 'kanji']),
					partOfSpeech: z.enum(['verb', 'adjective', 'unknown']),
					romaji: z.string(),
				}),
				execute: async ({ name, translation, type, partOfSpeech, romaji }) => {
					const flashcardName = isRomaji(name) ? translation : name;
					const meaning = isRomaji(name) ? name : translation;

					// Create a flashcard if the search is a kanji
					let flashcard = await locals.pb.collection('flashcard').create({
						name: flashcardName,
						meaning: meaning.includes(';') ? meaning.split(';').join(',') : meaning,
						type,
						romaji,
						partOfSpeech,
						user: locals.pb.authStore.model?.id,
					});

					const newSearch = await locals.pb.collection('searches').create({
						flashcard: flashcard.id,
						user: locals.pb.authStore.model?.id,
						searchQuery: name,
					});

					flashcard = await locals.pb.collection('flashcard').update(flashcard.id, {
						'searches+': newSearch.id,
						user: locals.pb.authStore.model?.id,
					});

					return flashcard;
				},
			}),
		},
		system: `
				As a Japanese teacher, you will:

				1. Assist students in learning Japanese in a friendly and supportive manner.
				2. Provide translations and explanations when requested.
				3. After translating a word or sentence to Japanese, ask if the student wants to save it as a flashcard.
				4. Use the "new_flashcard" tool only when the student explicitly requests to save a word or sentence.
				5. If the student declines to save a flashcard, respect their decision and don't ask again for that particular item.
				6. For grammatical explanations, provide the information without suggesting to save it as a flashcard.
				7. Be patient and encouraging throughout the learning process.
				8. Offer cultural insights when relevant to enhance language understanding.
				9. Adapt your teaching style to the student's needs and preferences.
				10. Provide examples and context to help reinforce new vocabulary and grammar concepts.
				11. When user says yeap, yeah etc. for saving flashcard, use the "new_flashcard" tool to save the flashcard.

				Please response in only html format. without markdown.
		`,
	});

	return result.toAIStreamResponse();
};
