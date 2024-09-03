import { kanji } from '$lib/static/kanji.js';
import { countKanji } from '$lib/utils';
import { flashcardCollectionSchema, quizSchema } from '$lib/utils/zodSchema';
import { fail } from '@sveltejs/kit';
import type { RecordModel } from 'pocketbase';
import { superValidate, setError } from 'sveltekit-superforms';
import { zod } from 'sveltekit-superforms/adapters';

export const load = async ({ locals, parent }) => {
	// Get all the flashcards collection
	const { isLoggedIn } = await parent();

	if (!isLoggedIn) {
		const flashcardCollections = await locals.pb.collection('flashcardCollections').getFullList({
			filter: `type = "original"`,
		});

		// Get collection ids
		const flashcardCollectionsIds = flashcardCollections.map((collection) => collection.id);

		const conditions = flashcardCollectionsIds.map((id) => {
			return `flashcardCollection = "${id}"`;
		});

		// Get all flashboxes from the flashcard collection ids
		const flashcardBoxes = await locals.pb.collection('flashcardBoxes').getFullList({
			filter: conditions.join('||'),
			sort: '-created',
		});

		// Add the flashcardBoxes to the flashcardCollections object
		flashcardCollections.forEach((collection) => {
			collection.expand = {
				flashcardBoxes: flashcardBoxes.filter((box) => box.flashcardCollection === collection.id),
			};
		});

		return {
			form: await superValidate(zod(flashcardCollectionSchema), {
				id: 'collection',
			}),
			quizForm: await superValidate(zod(quizSchema)),
			boxForm: await superValidate(zod(flashcardCollectionSchema), {
				id: 'box',
			}),
			flashcardCollections,
		};
	}

	const flashcardCollections = await locals.pb.collection('flashcardCollections').getFullList({
		filter: `userId = "${locals.pb.authStore.model?.id}" || type = "original"`,
		expand: 'flashcardBoxes',
		sort: '+created',
	});

	// Get all the flashcard from the server
	const flashcards = await locals.pb.collection('flashcardCount').getFullList();

	const flashcardBoxes: RecordModel[] = [];

	// Add the "count" field to each flashcardBox object
	flashcardCollections.forEach((collection) => {
		if (!collection.expand) return;

		// Sort the flashcard boxes by updated
		collection.expand.flashcardBoxes.sort((a: { updated: Date }, b: { updated: Date }) => {
			if (a.updated > b.updated) return -1;
			if (a.updated < b.updated) return 1;
			return 0;
		});

		// Get the flashcard boxes
		flashcardBoxes.push(...collection.expand.flashcardBoxes);

		collection.expand.flashcardBoxes.forEach((box: { count: number; id: string }) => {
			box.count = flashcards.filter((flashcard) => flashcard.id === box.id)[0].count;
		});
	});

	// TODO: Optimize this code
	for (const box of flashcardBoxes) {
		if (box.kanjiCount !== 0 || box.quizCount !== 0) continue;

		let kanjiCount = 0;
		let quizCount = 0;

		// Get the flashcards from the server
		const flashcards = await locals.pb.collection('flashcard').getFullList({
			filter: `flashcardBox = "${box.id}"`,
		});

		// Get the kanji count
		for (const flashcard of flashcards) if (countKanji(flashcard.name)) kanjiCount++;

		// Get the quiz count
		const quizzes = await locals.pb.collection('quizzes').getFullList({
			filter: `flashcardBox = "${box.id}"`,
		});

		quizCount = quizzes.length;

		// Update the flashcard box
		locals.pb.collection('flashcardBoxes').update(box.id, {
			kanjiCount,
			quizCount,
		});
	}

	return {
		form: await superValidate(zod(flashcardCollectionSchema), {
			id: 'collection',
		}),
		quizForm: await superValidate(zod(quizSchema)),
		boxForm: await superValidate(zod(flashcardCollectionSchema), {
			id: 'box',
		}),
		flashcardCollections,
	};
};

export const actions = {
	add: async ({ request, locals }) => {
		const form = await superValidate(request, zod(flashcardCollectionSchema));

		// Convenient validation check:
		if (!form.valid) return fail(400, { form });

		if (form.id === 'collection') {
			try {
				// Create a new collection of flashcards
				const newCollection = await locals.pb.collection('flashcardCollections').create({
					name: form.data.name,
					description: form.data.description,
					userId: locals?.pb.authStore.model?.id,
					type: 'custom',
				});

				form.data.id = newCollection.id;
				//@ts-ignore
				form.data.formAction = 'add';

				await locals.pb.collection('users').update(locals?.pb.authStore.model?.id, {
					'flashcardCollections+': newCollection.id,
				});

				return { form };
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
					flashcardCollection: form.data.flashcardCollection,
				});

				// Update the flashcard collection
				await locals.pb.collection('flashcardCollections').update(form.data.flashcardCollection, {
					'flashcardBoxes+': flashcardBox.id,
				});

				// Set the id of the flashcard box
				form.data.id = flashcardBox.id;
			} catch (_) {
				return setError(form, 'name', 'Flashcardbox already exists');
			}
		}
		return { form };
	},
	update: async ({ request, locals }) => {
		const form = await superValidate(request, zod(flashcardCollectionSchema));

		// Convenient validation check:
		if (!form.valid) return fail(400, { form });

		// Check if the id is provided
		if (!form.data.id) return fail(400, { form });

		if (form.id === 'collection') {
			try {
				// Create a new collection of flashcards
				const newCollection = await locals.pb
					.collection('flashcardCollections')
					.update(form.data.id, {
						name: form.data.name,
						description: form.data.description,
					});

				form.data.id = newCollection.id;
				//@ts-ignore
				form.data.formAction = 'update';

				return { form };
			} catch (_) {
				return setError(form, 'name', 'Collection cannot be edited now.');
			}
		} else {
			try {
				// Create a new flashcard box
				await locals.pb.collection('flashcardBoxes').update(form.data.id, {
					name: form.data.name,
					description: form.data.description,
				});
			} catch (_) {
				return setError(form, 'name', 'Flashcardbox cannot be edited now.');
			}
		}

		return { form };
	},
	delete: async ({ request, locals }) => {
		const form = await superValidate(request, zod(flashcardCollectionSchema));

		// Convenient validation check:
		if (!form.valid) return fail(400, { form });

		// Check if the id is provided
		if (!form.data.id) return fail(400, { form });

		if (form.id === 'collection') {
			try {
				// Delete the flashcard
				await locals.pb.collection('flashcardCollections').delete(form.data.id);

				//@ts-ignore
				form.data.formAction = 'delete';

				return { form };
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
		const form = await superValidate(request, zod(quizSchema));

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
		if (selectedQuizItems && selectedQuizItems.length > 0 && selectedQuizItems[0] === '')
			selectedQuizItems.shift();

		if (selectedQuizItems && selectedQuizItems.length > 0 && +form.data.startCount === 1) {
			// Find all the flashcards
			selectedQuizItems.forEach((item) => {
				const splitted = item.split('=');
				flashcards.push({
					name: splitted[0],
					meaning: splitted[1].slice(0, -1),
				});
			});
		} else {
			// Fetch the flashcards from the server
			flashcards = await locals.pb.collection('flashcard').getFullList({
				filter: `flashcardBox = "${form.data.flashcardBox}"`,
				fields: 'name,meaning',
			});
		}

		try {
			// Get all quizzes in the box
			const quizzes = await locals.pb.collection('quizzes').getFullList({
				filter: `flashcardBox = "${form.data.flashcardBox}" && userId = "${locals.pb.authStore.model?.id}"`,
			});

			// Update the flashcard box
			await locals.pb.collection('flashcardBoxes').update(form.data.flashcardBox, {
				quizCount: quizzes.length + 1,
			});
		} catch (e) {
			console.log('error', e);
		}

		try {
			const quiz = await locals.pb.collection('quizzes').create({
				name: form.data.name,
				choice: form.data.choice,
				type: form.data.type,
				userId: locals.pb.authStore.model?.id,
				maxCount: +form.data.maxCount,
				startCount: +form.data.startCount,
				flashcardBox: form.data.flashcardBox,
				timeLimit: form.data.timeLimit,
				flashcards,
			});

			form.data.id = quiz.id;

			await locals.pb.collection('users').update(locals?.pb.authStore.model?.id, {
				'quizzes+': quiz.id,
			});
		} catch (_) {
			return setError(form, 'name', 'Cannot create a quiz. Try again later.');
		}

		return { form };
	},
	addKanjiQuiz: async ({ request, locals }) => {
		const form = await superValidate(request, zod(quizSchema));

		// Convenient validation check:
		if (!form.valid) return fail(400, { form });

		// Check if user selected custom flashcards
		const selectedQuizItems = form.data.selectedQuizItems?.split('---');

		// Create the flashcards
		let flashcards: {
			name: string;
			meaning: string;
			onyomi?: string;
			kunyomi?: string;
		}[] = [];

		// Remove the first item from selectedQuizItems if it is empty
		if (selectedQuizItems && selectedQuizItems.length > 0 && selectedQuizItems[0] === '')
			selectedQuizItems.shift();

		if (selectedQuizItems && selectedQuizItems.length > 0 && +form.data.startCount === 1) {
			// Find all the flashcards
			selectedQuizItems[0].split(',').forEach((item) => {
				// Find the kanji in the kanji object
				const foundKanji = kanji[item];

				if (foundKanji) {
					flashcards.push({
						name: item,
						meaning: foundKanji.meaning,
						onyomi: foundKanji.onyomi.join(','),
						kunyomi: foundKanji.kunyomi.join(','),
					});
				}
			});
		} else {
			// Convert to an array
			const kanjiArray = Object.entries(kanji);

			flashcards = kanjiArray.slice(0, +form.data.maxCount).map((kanji) => {
				return {
					name: kanji[0],
					meaning: kanji[1].meaning,
					onyomi: kanji[1].onyomi.join(','),
					kunyomi: kanji[1].kunyomi.join(','),
				};
			});
		}
		try {
			const quiz = await locals.pb.collection('quizzes').create({
				name: form.data.name,
				choice: form.data.choice,
				type: form.data.type,
				userId: locals.pb.authStore.model?.id,
				maxCount: +form.data.maxCount,
				startCount: +form.data.startCount,
				timeLimit: form.data.timeLimit,
				flashcards,
			});

			form.data.id = quiz.id;

			await locals.pb.collection('users').update(locals?.pb.authStore.model?.id, {
				'quizzes+': quiz.id,
			});
		} catch (_) {
			return setError(form, 'name', 'Cannot create a quiz. Try again later.');
		}

		return { form };
	},
};
