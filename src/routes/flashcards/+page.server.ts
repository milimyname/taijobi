import { superValidate } from 'sveltekit-superforms/server';
import { fail, redirect } from '@sveltejs/kit';
import { flashcardCollectionSchema, quizSchema } from '$lib/utils/zodSchema';

/** @type {import('./$types').PageServerLoad} */
export const load = async ({ locals }) => {
	// Get all the flashcards collection
	const flashcardCollections = await locals.pb.collection('flashcardCollections').getFullList({
		filter: `userId = "${locals.pb.authStore.model?.id}" || type = "original"`,
		expand: 'flashcardBoxes'
	});

	// Get all the flashcard from the server
	const flashcards = await locals.pb.collection('flashcardCount').getFullList();

	// Add the "count" field to each flashcardBox object
	flashcardCollections.forEach((collection) => {
		if (!collection.expand) return;

		// Sort the flashcard boxes by updated
		collection.expand.flashcardBoxes.sort((a: { updated: Date }, b: { updated: Date }) => {
			if (a.updated > b.updated) return -1;
			if (a.updated < b.updated) return 1;
			return 0;
		});

		collection.expand.flashcardBoxes.forEach((box: { count: number; id: string }) => {
			box.count = flashcards.filter((flashcard) => flashcard.id === box.id)[0].count;
		});
	});

	// Server API:
	const form = await superValidate(flashcardCollectionSchema, {
		id: 'collection'
	});
	const boxForm = await superValidate(flashcardCollectionSchema, {
		id: 'box'
	});
	const quizForm = await superValidate(quizSchema, {
		id: 'quiz'
	});

	return {
		form,
		quizForm: quizForm,
		flashcardCollections,
		boxForm
	};
};

/** @type {import('./$types').Actions} */
export const actions = {
	add: async ({ request, locals }) => {
		const form = await superValidate(request, flashcardCollectionSchema);

		// Convenient validation check:
		if (!form.valid) return fail(400, { form });

		if (form.id === 'collection') {
			try {
				// Create a new collection of flashcards
				await locals.pb.collection('flashcardCollections').create({
					name: form.data.name,
					description: form.data.description,
					userId: locals?.pb.authStore.model?.id
				});
			} catch (_) {
				form.errors.name = ['Name already exists'];
				return { form };
			}
		} else {
			try {
				if (!form.data.flashcardCollection) throw new Error('No flashcard collection id provided');

				// Create a new flashcard box
				const flashcardBox = await locals.pb.collection('flashcardBoxes').create({
					name: form.data.name,
					description: form.data.description,
					userId: locals?.pb.authStore.model?.id,
					flashcardCollection: form.data.flashcardCollection
				});

				// Update the flashcard collection
				await locals.pb.collection('flashcardCollections').update(form.data.flashcardCollection, {
					'flashcardBoxes+': flashcardBox.id
				});
			} catch (_) {
				form.errors.name = ['Name already exists'];
				return { form };
			}
		}
		return { form };
	},
	edit: async ({ request, locals }) => {
		const form = await superValidate(request, flashcardCollectionSchema);

		// Convenient validation check:
		if (!form.valid) return fail(400, { form });

		// Check if the id is provided
		if (!form.data.id) return fail(400, { form });

		if (form.id === 'collection') {
			try {
				// Create a new collection of flashcards
				await locals.pb.collection('flashcardCollections').update(form.data.id, {
					name: form.data.name,
					description: form.data.description
				});
			} catch (_) {
				form.errors.name = ['Name already exists'];
				return { form };
			}
		} else {
			try {
				// Create a new flashcard box
				await locals.pb.collection('flashcardBoxes').update(form.data.id, {
					name: form.data.name,
					description: form.data.description
				});
			} catch (_) {
				form.errors.name = ['Name already exists'];
				return { form };
			}
		}

		return { form };
	},
	delete: async ({ request, locals }) => {
		const form = await superValidate(request, flashcardCollectionSchema);

		// Convenient validation check:
		if (!form.valid) return fail(400, { form });

		// Check if the id is provided
		if (!form.data.id) return fail(400, { form });

		if (form.id === 'collection') {
			try {
				// Delete the flashcard
				await locals.pb.collection('flashcardCollections').delete(form.data.id);
			} catch (_) {
				form.errors.name = ['Cannot delete flashcard'];
				return { form };
			}
		} else {
			try {
				// Create a new flashcard box
				await locals.pb.collection('flashcardBoxes').delete(form.data.id);
			} catch (_) {
				form.errors.name = ['Name already exists'];
				return { form };
			}
		}

		return { form };
	},
	addQuiz: async ({ request, locals }) => {
		const form = await superValidate(request, quizSchema);

		// Convenient validation check:
		if (!form.valid) return fail(400, { form });

		let quiz;

		// Get the current flashcards
		const flashcards = await locals.pb.collection('flashcard').getFullList({
			filter: `flashcardBox = "${form.data.flashcardBox}"`,
			fields: 'name,meaning'
		});

		try {
			quiz = await locals.pb.collection('quizzes').create({
				name: form.data.name,
				choice: form.data.choice,
				type: form.data.type,
				userId: locals.pb.authStore.model?.id,
				maxCount: form.data.maxCount,
				flashcardBox: form.data.flashcardBox,
				timeLimit: form.data.timeLimit,
				flashcards: JSON.stringify(flashcards)
			});
		} catch (_) {
			form.errors.name = ['No idea what happened'];
			return { form };
		}

		throw redirect(303, `/quizzes/${quiz.id}`);
	}
};
