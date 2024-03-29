import { superValidate, setError } from 'sveltekit-superforms/server';
import { fail, redirect } from '@sveltejs/kit';
import { flashcardCollectionSchema, quizSchema } from '$lib/utils/zodSchema';

/** @type {import('./$types').PageServerLoad} */
export const load = async ({ locals, parent }) => {
	// Get all the flashcards collection

	const { isLoggedIn } = await parent();
	if (!isLoggedIn) {
		const flashcardCollections = await locals.pb.collection('flashcardCollections').getFullList({
			filter: `type = "original"`
		});

		// Get collection ids
		const flashcardCollectionsIds = flashcardCollections.map((collection) => collection.id);

		const conditions = flashcardCollectionsIds.map((id) => {
			return `flashcardCollection = "${id}"`;
		});

		// Get all flashboxes from the flashcard collection ids
		const flashcardBoxes = await locals.pb.collection('flashcardBoxes').getFullList({
			filter: conditions.join('||'),
			sort: '-created'
		});

		// Add the flashcardBoxes to the flashcardCollections object
		flashcardCollections.forEach((collection) => {
			collection.expand = {
				flashcardBoxes: flashcardBoxes.filter((box) => box.flashcardCollection === collection.id)
			};
		});

		return {
			form: await superValidate(flashcardCollectionSchema, {
				id: 'collection'
			}),
			quizForm: await superValidate(quizSchema, {
				id: 'quiz'
			}),
			boxForm: await superValidate(flashcardCollectionSchema, {
				id: 'box'
			}),
			flashcardCollections
		};
	}

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

	return {
		form: await superValidate(flashcardCollectionSchema, {
			id: 'collection'
		}),
		quizForm: await superValidate(quizSchema, {
			id: 'quiz'
		}),
		boxForm: await superValidate(flashcardCollectionSchema, {
			id: 'box'
		}),
		flashcardCollections
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
					userId: locals?.pb.authStore.model?.id,
					type: 'custom'
				});
			} catch (_) {
				return setError(form, 'name', 'Collection already exists');
			}
		} else {
			try {
				if (!form.data.flashcardCollection)
					return setError(form, 'name', 'No flashcard collection id provided');

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
				return setError(form, 'name', 'Flashcardbox already exists');
			}
		}
		return { form };
	},
	update: async ({ request, locals }) => {
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
				return setError(form, 'name', 'Collection cannot be edited now.');
			}
		} else {
			try {
				// Create a new flashcard box
				await locals.pb.collection('flashcardBoxes').update(form.data.id, {
					name: form.data.name,
					description: form.data.description
				});
			} catch (_) {
				return setError(form, 'name', 'Flashcardbox cannot be edited now.');
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
				return setError(form, 'name', 'Collection cannot be deleted now.');
			}
		} else {
			try {
				// Create a new flashcard box
				await locals.pb.collection('flashcardBoxes').delete(form.data.id);
			} catch (_) {
				return setError(form, 'name', 'Flashcardbox cannot be deleted now.');
			}
		}

		return { form };
	},
	addQuiz: async ({ request, locals }) => {
		const form = await superValidate(request, quizSchema);

		// Convenient validation check:
		if (!form.valid) return fail(400, { form });

		// Check if user selected custom flashcards
		const selectedQuizItems = form.data.selectedQuizItems?.split('---');

		// Create the flashcards
		let flashcards: {
			name: string;
			meaning: string;
		}[] = [];

		// Remove the first item from selectedQuizItems if it is empty
		if (selectedQuizItems && selectedQuizItems[0] === '') selectedQuizItems.shift();

		if (selectedQuizItems && +form.data.startCount === 1) {
			// Find all the flashcards
			selectedQuizItems.forEach((item) => {
				const splitted = item.split('=');
				flashcards.push({
					name: splitted[0],
					meaning: splitted[1].slice(0, -1)
				});
			});
		} else {
			// Fetch the flashcards from the server
			flashcards = await locals.pb.collection('flashcard').getFullList({
				filter: `flashcardBox = "${form.data.flashcardBox}"`,
				fields: 'name,meaning'
			});
		}

		let quiz;

		try {
			quiz = await locals.pb.collection('quizzes').create({
				name: form.data.name,
				choice: form.data.choice,
				type: form.data.type,
				userId: locals.pb.authStore.model?.id,
				maxCount: +form.data.maxCount,
				startCount: +form.data.startCount,
				flashcardBox: form.data.flashcardBox,
				timeLimit: form.data.timeLimit,
				flashcards
			});
		} catch (_) {
			return setError(form, 'name', 'Cannot create a quiz. Try again later.');
		}

		throw redirect(303, `/quizzes/${quiz.id}`);
	}
};
