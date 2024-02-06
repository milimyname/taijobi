import { superValidate, setError } from 'sveltekit-superforms/server';
import { fail, redirect } from '@sveltejs/kit';
import { quizSchema } from '$lib/utils/zodSchema';
import { kanji } from '$lib/static/kanji.js';
import type Pocketbase from 'pocketbase';

/** @type {import('./$types').PageServerLoad} */
export const load = async ({ locals, parent }) => {
	try {
		const { isLoggedIn } = await parent();

		if (!isLoggedIn)
			return {
				quizForm: await superValidate(quizSchema)
			};

		const kanjiId = await getOrCreateKanjiId(locals.pb, locals.pb.authStore.model?.id);

		const flashcard = await locals.pb.collection('flashcard').getFullList({
			filter: `flashcardBox = "${kanjiId}"`,
			fields: 'name'
		});

		return {
			flashcard: structuredClone(flashcard),
			kanjiId,
			quizForm: await superValidate(quizSchema)
		};
	} catch (e) {
		console.error(e);
		return fail(500, { message: 'Something went wrong' });
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
		type: 'custom',
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

		// Get the kanji collection from
		const kanjiId = await getOrCreateKanjiId(locals.pb, userId);

		// Check if user selected custom flashcards
		const selectedQuizItems = form.data.selectedQuizItems?.split(',');

		// Create the flashcards
		let flashcards: {
			name: string;
			meaning: string;
			kunyomi: string;
			onyomi: string;
		}[] = [];

		if (selectedQuizItems && form.data.startCount === 1) {
			// Find all the flashcards
			selectedQuizItems.forEach((item) => {
				flashcards.push({
					name: item,
					meaning: kanji[item].meaning,
					kunyomi: kanji[item].kunyomi.join(', '),
					onyomi: kanji[item].onyomi.join(', ')
				});
			});
		} else {
			// Get the kanji collection from
			const arrKanji = Object.entries(kanji).map(([key, value]) => {
				return {
					name: key,
					meaning: value.meaning,
					kunyomi: value.kunyomi.join(', '),
					onyomi: value.onyomi.join(', ')
				};
			});

			flashcards = arrKanji.slice(
				form.data.startCount - 1,
				form.data.startCount + form.data.maxCount
			);
		}

		// Quiz Model
		let quiz;

		try {
			quiz = await locals.pb.collection('quizzes').create({
				name: form.data.name,
				choice: form.data.choice,
				type: form.data.type,
				userId,
				maxCount: form.data.maxCount,
				startCount: form.data.startCount,
				flashcardBox: kanjiId,
				timeLimit: form.data.timeLimit,
				flashcards: JSON.stringify(flashcards)
			});
		} catch (_) {
			return setError(form, 'name', `Error creating quiz. Please try again.`);
		}

		throw redirect(303, `/quizzes/${quiz.id}`);
	}
};
