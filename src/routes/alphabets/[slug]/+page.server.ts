import { kanji } from '$lib/static/kanji';
import { quizSchema } from '$lib/utils/zodSchema';
import { fail, redirect } from '@sveltejs/kit';
import type Pocketbase from 'pocketbase';
import { superValidate, setError } from 'sveltekit-superforms';
import { zod } from 'sveltekit-superforms/adapters';

export const load = async ({ locals, parent }) => {
	try {
		const { isLoggedIn } = await parent();

		if (!isLoggedIn)
			return {
				quizForm: await superValidate(zod(quizSchema)),
			};

		const kanjiId = await getOrCreateKanjiId(locals.pb, locals.pb.authStore.model?.id);

		const flashcard = await locals.pb.collection('flashcard').getFullList({
			filter: `flashcardBox = "${kanjiId}"`,
			fields: 'name',
		});

		return {
			flashcard: structuredClone(flashcard),
			kanjiId,
			quizForm: await superValidate(zod(quizSchema)),
		};
	} catch (e) {
		console.error(e);
		return fail(500, { message: 'Something went wrong' });
	}
};

async function getOrCreateKanjiId(pb: Pocketbase, userId: string) {
	const existingFlashcardBoxes = await pb.collection('flashcardBoxes').getFullList({
		filter: `userId = "${userId}" && name = "漢字"`,
	});

	// If the user already has a flashcard box, return it
	if (existingFlashcardBoxes.length > 0) return existingFlashcardBoxes[0].id;

	const taijobiCollection = await pb
		.collection('flashcardCollections')
		.getFirstListItem(`name="Taijobi" && userId="${userId}"`);

	const flashcardBox = await pb.collection('flashcardBoxes').create({
		name: '漢字',
		userId,
		description: 'It is a list of saved kanji.',
		flashcardCollection: taijobiCollection.id,
	});

	await pb.collection('users').update(userId, {
		'flashcardCollections+': taijobiCollection.id,
	});

	await pb.collection('flashcardCollections').update(taijobiCollection.id, {
		'flashcardBoxes+': flashcardBox.id,
	});

	return flashcardBox.id;
}

export const actions = {
	addQuiz: async ({ request, locals }) => {
		const form = await superValidate(request, zod(quizSchema));

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

		if (selectedQuizItems && +form.data.startCount === 1) {
			// Find all the flashcards
			selectedQuizItems.forEach((item) => {
				flashcards.push({
					name: item,
					meaning: kanji[item].meaning,
					kunyomi: kanji[item].kunyomi.join(', '),
					onyomi: kanji[item].onyomi.join(', '),
				});
			});
		} else {
			// Get the kanji collection from
			const arrKanji = Object.entries(kanji).map(([key, value]) => {
				return {
					name: key,
					meaning: value.meaning,
					kunyomi: value.kunyomi.join(', '),
					onyomi: value.onyomi.join(', '),
				};
			});

			flashcards = arrKanji.slice(
				+form.data.startCount - 1,
				+form.data.startCount + +form.data.maxCount,
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
				maxCount: +form.data.maxCount,
				startCount: +form.data.startCount,
				flashcardBox: kanjiId,
				timeLimit: form.data.timeLimit,
				flashcards: JSON.stringify(flashcards),
			});

			await locals.pb.collection('users').update(locals?.pb.authStore.model?.id, {
				'quizzes+': quiz.id,
			});
		} catch (_) {
			return setError(form, 'name', `Error creating quiz. Please try again.`);
		}

		throw redirect(303, `/games/quizzes/${quiz.id}`);
	},
};
