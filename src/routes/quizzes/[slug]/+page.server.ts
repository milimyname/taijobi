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
			isKanjiQuiz: false,
			flashcards,
			userId: locals.pb.authStore.model?.id || '-'
		};
	}

	// Get a quiz
	const [quiz] = await locals.pb
		.collection('quizzes')
		.getFullList({ filter: `id = "${params.slug}"` });

	// Remove unnecessary flashcards from the quiz
	// const removedCount = +quiz.maxCount % +quiz.choice;

	// Get all the flashcards from the quiz
	const items = quiz.flashcards;

	// Remove the first `removedCount` elements from the shuffled array
	const slicedItems = items.splice(0, +quiz.maxCount);

	// Shuffle the flashcards array
	shuffleArray(slicedItems);

	return {
		quiz,
		flashcards: slicedItems,
		userId: locals.pb.authStore.model?.id,
		isKanjiQuiz: true
	};
};
