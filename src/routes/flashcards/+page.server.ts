import type { PageServerLoad } from './$types';

export const load = (async ({ locals }) => {
	// Get all the flashcards
	const flashcards = await locals.pb.collection('flashcards').getFullList({
		sort: '+created'
	});

	return { flashcards: structuredClone(flashcards) };
}) satisfies PageServerLoad;
