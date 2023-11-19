import { superValidate } from 'sveltekit-superforms/server';
import { fail, redirect } from '@sveltejs/kit';
import { flashcardsSchema, quizSchema } from '$lib/utils/zodSchema';

/** @type {import('./$types').PageServerLoad} */
export const load = async ({ locals }) => {
	// Get user id from authStore
	const { id } = await locals.pb.authStore.model;

	// Get all the flashcards collection
	const flashcardsCollection = await locals.pb.collection('flashcards').getFullList(100, {
		filter: `userId = "${id}" || name = "一日" || name = "慣用句"`
	});

	// Get all the flashcard from the server
	const flashcards = await locals.pb.collection('flashcard').getFullList();

	const counts = await Promise.all(
		flashcardsCollection.map(async (collection) => {
			// Get the amount of flashcards in each collection
			const count = flashcards.filter(
				(flashcard) => flashcard.flashcardsId === collection.id
			).length;

			return {
				count
			};
		})
	);

	// Add the "count" field to each collection object
	flashcardsCollection.forEach((collection, index) => {
		collection.count = counts[index].count;
	});

	console.log(flashcardsCollection)

	// Server API:
	const form = await superValidate(flashcardsSchema);
	const quizForm = await superValidate(quizSchema);

	return {
		form,
		quizForm: quizForm,
		flashcards: structuredClone(flashcardsCollection)
	};
};

/** @type {import('./$types').Actions} */
export const actions = {
	add: async ({ request, locals }) => {
		const form = await superValidate(request, flashcardsSchema);

		// Convenient validation check:
		if (!form.valid) return fail(400, { form });

		// Get user id from authStore
		const { id } = await locals.pb.authStore.model;

		let folder_flashcards;

		try {
			// Create a new collection of flashcards
			folder_flashcards = await locals.pb
				.collection('flashcards')
				.create({ name: form.data.name, description: form.data.description, userId: id });
		} catch (_) {
			form.errors.name = ['Name already exists'];
			return { form };
		}

		throw redirect(303, `/flashcards/${folder_flashcards.id}`);
	},
	edit: async ({ request, locals }) => {
		const form = await superValidate(request, flashcardsSchema);

		// Convenient validation check:
		if (!form.valid) return fail(400, { form });

		try {
			// Update the flashcard
			await locals.pb.collection('flashcards').update(form.data.id, {
				name: form.data.name,
				description: form.data.description
			});
		} catch (_) {
			form.errors.name = ['Name already exists'];
			return { form };
		}

		return { form };
	},
	delete: async ({ request, locals }) => {
		const form = await superValidate(request, flashcardsSchema);

		// Convenient validation check:
		if (!form.valid) return fail(400, { form });

		try {
			// Delete the flashcard
			await locals.pb.collection('flashcards').delete(form.data.id);
		} catch (_) {
			form.errors.name = ['Cannot delete flashcard'];
			return { form };
		}

		return { form };
	},
	addQuiz: async ({ request, locals }) => {
		const form = await superValidate(request, quizSchema);

		// Convenient validation check:
		if (!form.valid) return fail(400, { form });

		// Set the form userId to the current user
		const userId = locals.pb.authStore.model?.id;

		let quiz;

		// Get the current flashcards
		const flashcards = (
			await locals.pb.collection('flashcard').getFullList({
				filter: `flashcardsId = "${form.data.flashcardsId}"`
			})
		).map((card) => {
			return { name: card.name, meaning: card.meaning };
		});

		try {
			quiz = await locals.pb.collection('quizzes').create({
				name: form.data.name,
				choice: form.data.choice,
				type: form.data.type,
				userId,
				maxCount: form.data.maxCount,
				flashcardsId: form.data.flashcardsId,
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
