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

	// Get the flashcards from the quiz
	// If the startCount is 1, then slice the items from 0 to maxCount (custom flashcards)
	// If the startCount is not 1, then slice the items from startCount to maxCount
	const items =
		+quiz.startCount === 1
			? quiz.flashcards
			: quiz.flashcards.slice(+quiz.startCount, +quiz.maxCount);

	// Shuffle the flashcards array
	shuffleArray(items);

	return {
		quiz,
		flashcards: items,
		userId: locals.pb.authStore.model?.id,
		isKanjiQuiz: true
	};
};
