import { conjugationFormSchema } from '$lib/utils/zodSchema.js';
import { redirect } from '@sveltejs/kit';
import type { RecordModel } from 'pocketbase';
import { fail, setError, superValidate } from 'sveltekit-superforms';
import { zod } from 'sveltekit-superforms/adapters';

export const load = async ({ locals }) => {
	// If user is not logged in, do nothing
	if (!locals.pb.authStore.isValid) redirect(303, '/login');

	// Get a quiz
	const ogCollections = await locals.pb.collection('flashcardCollections').getFullList({
		filter: `userId = "${locals.pb.authStore.model?.id}" || type = "original"`,
		expand: 'flashcardBoxes.flashcards',
		fields: 'type,expand,expand.flashcardBoxes.expand.name',
	});

	// Simplify data
	const ogFlashcardBoxes = ogCollections
		.flatMap((collection) => {
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
					flashcards: flashcardBox.expand.flashcards
						.filter(
							(flashcard: RecordModel) =>
								flashcard.partOfSpeech === 'adjective' || flashcard.partOfSpeech === 'verb',
						)
						.map((flashcard: RecordModel) => ({
							name: flashcard.name,
							id: flashcard.id,
							partOfSpeech: flashcard.partOfSpeech,
							type: flashcard.type,
							meaning: flashcard.meaning,
						})),
				};
			});
		})
		.filter((flashcardBox) => flashcardBox.flashcards.length > 0);

	const conjugations = await locals.pb.collection('conjugations').getFullList({
		filter: `user = "${locals.pb.authStore.model?.id}"`,
		fields: 'id,name,created,type,settings',
	});

	return {
		form: await superValidate(zod(conjugationFormSchema)),
		ogFlashcardBoxes,
		conjugations,
	};
};

export const actions = {
	add: async ({ request, locals }) => {
		const form = await superValidate(request, zod(conjugationFormSchema));

		// Convenient validation check:
		if (!form.valid) return fail(400, { form });

		if (!form.data.flashcards)
			return setError(form, 'name', 'Please provide at least one flashcard.');

		const flashcards = form.data.flashcards;
		const adjectives = flashcards.some((card) => card.partOfSpeech === 'adjective');
		const verbs = flashcards.some((card) => card.partOfSpeech === 'verb');

		let type = 'mixed';
		if (adjectives && verbs) type = 'mixed';
		else if (adjectives) type = 'adjective';
		else if (verbs) type = 'verb';

		try {
			const newConjugation = await locals.pb.collection('conjugations').create({
				name: form.data.name,
				type,
				settings: form.data.settings,
				flashcards: flashcards.map((flashcard) => flashcard.id),
				user: locals?.pb.authStore.model?.id,
			});

			form.data.id = newConjugation.id;
		} catch (error) {
			console.log(error);
		}

		return { form };
	},
};
