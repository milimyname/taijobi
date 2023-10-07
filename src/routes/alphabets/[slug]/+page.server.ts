/** @type {import('./$types').PageServerLoad} */
export const load = async ({ locals }) => {
	// Get all the collection of flashcards
	const folderFlashcards = await locals.pb.collection('flashcards').getFullList();

	const { id } = locals.pb.authStore.model;

	// Check if there is a kanji collection
	let collection_kanji = folderFlashcards.find(
		(card: { name: string; userId: string }) => card.name === '漢字' && card.userId === id
	);
	// If there is no kanji collection, create one
	if (!collection_kanji)
		collection_kanji = await locals.pb.collection('flashcards').create({
			name: '漢字',
			userId: locals.pb.authStore.model.id,
			description: 'It is a list of saved kanji.'
		});

	// Get all flashcards
	const flashcard = await locals.pb.collection('flashcard').getFullList();

	return { flashcard: structuredClone(flashcard), kanji_id: collection_kanji.id };
};
