import { superValidate } from 'sveltekit-superforms/server';
import { fail, redirect } from '@sveltejs/kit';
import { quizSchema } from '$lib/utils/zodSchema';
import { kanji } from '$lib/static/kanji.js';
import type Pocketbase from 'pocketbase';

/** @type {import('./$types').PageServerLoad} */
export const load = async ({ locals }) => {
	try {
		const kanjiId = await getOrCreateKanjiId(locals.pb, locals.pb.authStore.model?.id);

		const flashcard = await locals.pb.collection('flashcard').getFullList({
			filter: `flashcardBox = "${kanjiId}"`,
			fields: 'name'
		});

		const quizForm = await superValidate(quizSchema);

		return { flashcard: structuredClone(flashcard), kanjiId, quizForm };
	} catch (e) {
		console.error(e);
		return fail(500, 'Internal Server Error');
	}
};

async function getOrCreateKanjiId(pb: Pocketbase, userId: string) {
	const existingFlashcards = await pb.collection('flashcardBoxes').getFullList({
		filter: `userId = "${userId}" && name = "漢字"`
	});

	// If the user already has a flashcard box, return it
	if (existingFlashcards.length > 0) return existingFlashcards[0].id;

	const flashcardBox = await pb.collection('flashcardBoxes').create({
		name: '漢字',
		userId,
		description: 'It is a list of saved kanji.'
	});

	await pb.collection('flashcardCollections').create({
		name: 'Taijobi',
		description: 'It is a list of saved flashcards by Taijobi.',
		userId: userId,
		'flashcardBoxes+': flashcardBox.id
	});

	return flashcardBox.id;
}

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
			return {
				name: key,
				meaning: value.meaning,
				kunyomi: value.kunyomi.join(', '),
				onyomi: value.onyomi.join(', ')
			};
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
				flashcardBox: kanjiId,
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
