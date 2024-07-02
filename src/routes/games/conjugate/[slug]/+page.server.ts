import { hiragana } from '$lib/static/hiragana';
import { katakana } from '$lib/static/katakana';
import { shuffleArray } from '$lib/utils/actions';
import { name } from '@melt-ui/svelte';
import PocketBase, { type RecordModel } from 'pocketbase';
import { toRomaji } from 'wanakana';

// Create demo data for hiragana and katakana quizzes
async function createDemoData(
	pb: PocketBase,
	fetch: typeof window.fetch,
	expandedFlashcard: RecordModel,
) {
	const data = await Promise.all(
		expandedFlashcard?.expand?.flashcards.map(async (flashcard: RecordModel) => {
			const conjugation = await fetch(`/api/conjugation`, {
				method: 'POST',
				headers: {
					'Content-Type': 'application/json',
				},
				body: JSON.stringify({ word: flashcard.name }),
			});

			return {
				id: flashcard.id,
				name: flashcard.name,
				conjugation: await conjugation.json(),
			};
		}),
	);

	return data;
}

export const load = async ({ params, locals, fetch }) => {
	if (params.slug === 'demo') {
		return {};
	}

	// Get a quiz
	const conjugation = await locals.pb.collection('conjugations').getOne(params.slug, {
		expand: 'flashcards',
		fields: 'id,flashcards,settings,expand',
	});

	const flashcards = await createDemoData(locals.pb, fetch, conjugation);

	return {
		conjugation: {
			id: conjugation.id,
			name: conjugation.name,
			flashcards: flashcards,
			settings: conjugation.settings,
		},
	};
};
