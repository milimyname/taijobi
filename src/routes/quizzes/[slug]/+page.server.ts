import { hiragana } from '$lib/static/hiragana';
import { katakana } from '$lib/static/katakana';
import { shuffleArray } from '$lib/utils/actions';
import { toRomaji } from 'wanakana';

/** @type {import('./$types').PageServerLoad} */
export const load = async ({ params, locals }) => {
	if (params.slug === 'hiragana' || params.slug === 'katakana') {
		// Return hiragana and katakana as items

		const obj = params.slug === 'hiragana' ? hiragana : katakana;

		const flashcards = Object.entries(obj).map(([key]) => {
			return { name: key, meaning: toRomaji(key) };
		});

		// Shuffle the flashcards array
		shuffleArray(flashcards);

		return {
			quiz: {
				flashcardBox: '-',
				id: params.slug,
				maxCount: 46,
				score: 0,
				timeLimit: false,
				choice: '4',
				type: 'name',
				userId: locals.pb.authStore.model?.id
			},
			flashcards,
			userId: locals.pb.authStore.model?.id
		};
	}

	// Get a quiz
	const [quiz] = await locals.pb
		.collection('quizzes')
		.getFullList({ filter: `id = "${params.slug}"` });

	// Remove unnecessary flashcards from the quiz
	const removedCount = quiz.maxCount % +quiz.type;

	const items = JSON.parse(quiz.flashcards);

	// Shuffle the flashcards array
	shuffleArray(items);

	// Remove the first `removedCount` elements from the shuffled array
	items.splice(0, removedCount);

	return { quiz, flashcards: items, userId: locals.pb.authStore.model?.id };
};
