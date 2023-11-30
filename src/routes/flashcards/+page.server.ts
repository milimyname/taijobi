import { superValidate } from 'sveltekit-superforms/server';
import { fail, redirect } from '@sveltejs/kit';
import { flashcardCollectionSchema, quizSchema } from '$lib/utils/zodSchema';

/** @type {import('./$types').PageServerLoad} */
export const load = async ({ locals }) => {
	// Get all the flashcards collection
	const flashcardCollections = await locals.pb.collection('flashcardCollections').getFullList({
		filter: `userId = "${locals.pb.authStore.model?.id}" || type = "original"`,
		expand: 'flashcardBox'
	});

	// Get all the flashcard from the server
	const flashcards = await locals.pb.collection('flashcardCount').getFullList();

	// Add the "count" field to each flashcardBox object
	flashcardCollections.forEach((collection) => {
		if (!collection.expand) return;

		collection.expand.flashcardBox.forEach((box) => {
			box.count = flashcards.filter((flashcard) => flashcard.id === box.id)[0].count;
		});
	});

	// Server API:
	const form = await superValidate(flashcardCollectionSchema);
	const quizForm = await superValidate(quizSchema);

	return {
		form,
		quizForm: quizForm,
		flashcardCollections
	};
};

/** @type {import('./$types').Actions} */
export const actions = {
	add: async ({ request, locals }) => {
		const form = await superValidate(request, flashcardCollectionSchema);

		// Convenient validation check:
		if (!form.valid) return fail(400, { form });

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

		return { form };
	},
	edit: async ({ request, locals }) => {
		const form = await superValidate(request, flashcardCollectionSchema);

		// Convenient validation check:
		if (!form.valid) return fail(400, { form });

		try {
			// Update the flashcard
			await locals.pb.collection('flashcardCollections').update(form.data.id, {
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
		const form = await superValidate(request, flashcardCollectionSchema);

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
