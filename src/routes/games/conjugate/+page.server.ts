import type { RecordModel } from 'pocketbase';

export const load = async ({ locals }) => {
	// If user is not logged in, do nothing
	if (!locals.pb.authStore.isValid) return;

	// Get a quiz
	const ogCollections = await locals.pb.collection('flashcardCollections').getFullList({
		filter: `userId = "${locals.pb.authStore.model?.id}" || type = "original"`,
		expand: 'flashcardBoxes.flashcards',
		fields: 'type,expand,expand.flashcardBoxes.expand.name',
	});

	// Simplify data
	const ogFlashcardBoxes = ogCollections.flatMap((collection) => {
		// First, check if the collection and its flashcardBoxes property exist
		if (!collection?.expand?.flashcardBoxes) return [];

		return collection.expand.flashcardBoxes.flatMap((flashcardBox: RecordModel) => {
			// Check if the flashcardBox itself is properly expanded
			if (!flashcardBox?.expand) return [];

			// Now map the flashcardBoxes, assuming the necessary expands are present
			return {
				collectionType: collection.type,
				flashcardBoxId: flashcardBox.id,
				flashcardBoxName: flashcardBox.name,
				flashcards: flashcardBox.expand.flashcards.map((flashcard: RecordModel) => ({
					name: flashcard.name,
					id: flashcard.id,
					partOfSpeech: flashcard.partOfSpeech,
					type: flashcard.type,
					meaning: flashcard.meaning,
				})),
			};
		});
	});

	return {
		ogFlashcardBoxes,
	};
};
