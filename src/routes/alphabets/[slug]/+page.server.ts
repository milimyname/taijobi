import type { PageServerLoad } from './$types';

export const load = (async ({ locals }) => {
	// Get all the collection of flashcards
	const folder_flashcards = await locals.pb.collection('flashcards').getFullList();

	// Check if there is a kanji collection
	let collection_kanji = folder_flashcards.find((card: { name: string }) => card.name === 'kanji');
	// If there is no kanji collection, create one
	if (!collection_kanji)
		collection_kanji = await locals.pb
			.collection('flashcards')
			.create({ name: 'kanji', user_id: locals.pb.authStore.model.id });

	// Get all flashcards
	const flashcard = await locals.pb.collection('flashcard').getFullList();

	return { flashcard: structuredClone(flashcard), kanji_id: collection_kanji.id };
}) satisfies PageServerLoad;
