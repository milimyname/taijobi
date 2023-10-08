import { shuffleArray } from '$lib/utils/actions';

/** @type {import('./$types').PageServerLoad} */
export const load = async ({ params, locals }) => {
	// Get a quiz
	const [quiz] = await locals.pb
		.collection('quizzes')
		.getFullList(100, { filter: `id = "${params.slug}"` });

	// Remove unnecessary flashcards from the quiz
	const removedCount = quiz.maxCount % +quiz.type;

	const { items } = await locals.pb
		.collection('flashcard')
		.getList(1, quiz.maxCount, { filter: `flashcardsId = "${quiz.flashcardsId}"` });

	// Shuffle the flashcards array
	shuffleArray(items);

	// Remove the first `removedCount` elements from the shuffled array
	items.splice(0, removedCount);

	return { quiz, flashcards: items, userId: locals.pb.authStore.model?.id };
};
