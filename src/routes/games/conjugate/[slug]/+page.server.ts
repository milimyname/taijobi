import { type RecordModel } from 'pocketbase';

// Create demo data for hiragana and katakana quizzes
async function createDemoData(fetch: typeof window.fetch, expandedFlashcard: RecordModel) {
	const data = await Promise.all(
		expandedFlashcard?.expand?.flashcards.map(async (flashcard: RecordModel) => {
			try {
				const res = await fetch(`/api/conjugation`, {
					method: 'POST',
					headers: {
						'Content-Type': 'application/json',
					},
					body: JSON.stringify({ word: flashcard.name }),
				});

				if (!res.ok) throw new Error('Failed to fetch conjugation data');

				const data = await res.json();

				// Only get the conjugation that the user selected
				const conjugation = await Promise.all(
					data.filter((c: { name: string }) => {
						return expandedFlashcard.settings.includes(c.name);
					}),
				);

				return {
					id: flashcard.id,
					name: flashcard.name,
					conjugation,
				};
			} catch (e) {
				console.error(e);
			}
		}),
	);

	return data;
}

export const load = async ({ params, locals, fetch }) => {
	if (params.slug === 'demo') return {};

	// Get a quiz
	const conjugation = await locals.pb.collection('conjugations').getOne(params.slug, {
		expand: 'flashcards',
		fields: 'id,flashcards,settings,expand',
	});

	const flashcards = await createDemoData(fetch, conjugation);

	return {
		conjugation: {
			id: conjugation.id,
			name: conjugation.name,
			flashcards: flashcards,
			settings: conjugation.settings,
		},
	};
};
