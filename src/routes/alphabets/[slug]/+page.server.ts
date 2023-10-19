import { superValidate } from 'sveltekit-superforms/server';
import { fail, redirect } from '@sveltejs/kit';
import { quizSchema } from '$lib/utils/zodSchema';
import { kanji } from '$lib/static/kanji.js';

let kanji_id = '';

/** @type {import('./$types').PageServerLoad} */
export const load = async ({ locals }) => {
	// Get all the collection of flashcards
	const folderFlashcards = await locals.pb.collection('flashcards').getFullList();

	const userId = locals.pb.authStore.model?.id;

	// Check if there is a kanji collection
	let collection_kanji = folderFlashcards.find(
		(card: { name: string; userId: string }) => card.name === '漢字' && card.userId === userId
	);
	// If there is no kanji collection, create one
	if (!collection_kanji)
		collection_kanji = await locals.pb.collection('flashcards').create({
			name: '漢字',
			userId,
			description: 'It is a list of saved kanji.'
		});

	// Get all flashcards
	const flashcard = await locals.pb.collection('flashcard').getFullList();

	const quizForm = await superValidate(quizSchema);

	kanji_id = collection_kanji?.id;

	return { flashcard: structuredClone(flashcard), kanji_id: collection_kanji?.id, quizForm };
};

/** @type {import('./$types').Actions} */
export const actions = {
	addQuiz: async ({ request, locals }) => {
		const form = await superValidate(request, quizSchema);

		// Convenient validation check:
		if (!form.valid) return fail(400, { form });

		// Set the form userId to the current user
		const userId = locals.pb.authStore.model?.id;

		let quiz;

		// Get the kanji collection from
		const arrKanji = Object.entries(kanji).map(([key, value]) => {
			return { name: key, meaning: value.meaning };
		});

		const flashcards = arrKanji.slice(
			form.data.startCount - 1,
			form.data.startCount + form.data.maxCount
		);

		try {
			quiz = await locals.pb.collection('quizzes').create({
				name: '漢字',
				choice: form.data.choice,
				type: form.data.type,
				userId,
				maxCount: form.data.maxCount,
				startCount: 2,
				flashcardsId: kanji_id,
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
