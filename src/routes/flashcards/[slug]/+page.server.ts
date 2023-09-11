import { superValidate } from 'sveltekit-superforms/server';
import { fail } from '@sveltejs/kit';
import { flashcardSchema } from '$lib/utils/zodSchema';
import Kuroshiro from '@sglkc/kuroshiro';
import KuromojiAnalyzer from 'kuroshiro-analyzer-kuromoji';
import { constantFlashcards } from '$lib/utils/constants.js';

const kuroshiro = new Kuroshiro();

let kuroshiroInitialized = false; // Add this flag to track initialization

// Disable server-side rendering:
export const ssr = true;

/** @type {import('./$types').PageServerLoad} */
export const load = async ({ locals, params }) => {
	if (!kuroshiroInitialized) {
		await kuroshiro.init(new KuromojiAnalyzer());
		kuroshiroInitialized = true;
	}

	// Check if slugs are constant
	const constantSlugs = constantFlashcards.includes(params.slug);

	// Get all the flashcards
	const flashcards = await locals.pb
		.collection('flashcard')
		.getFullList(100, { filter: `flashcards_id = "${params.slug}"` });

	// Check if they are kanji type
	const kanjiFlashcards = flashcards.filter((card) => card.type === 'kanji');

	if (kanjiFlashcards.length > 0 || constantSlugs) {
		// Server API:
		const form = await superValidate(flashcardSchema);

		return {
			form,
			flashcards: structuredClone(flashcards),
			isAdmin: locals.pb.authStore.model.role.includes('admin'),
			constantFlashcard: constantSlugs
		};
	}

	// Add furigana to the flashcards
	const furiganaPromises = structuredClone(flashcards);

	furiganaPromises.map(
		async (card) =>
			(card.furigana = await kuroshiro.convert(card.name, { to: 'hiragana', mode: 'furigana' }))
	);

	// Wait for all the Promises to resolve
	const furiganas = await Promise.all(furiganaPromises);

	// Server API:
	const form = await superValidate(flashcardSchema);

	return {
		form,
		flashcards: furiganas,
		isAdmin: locals.pb.authStore.model.role.includes('admin'),
		constantFlashcard: constantSlugs
	};
};

/** @type {import('./$types').Actions} */
export const actions = {
	add: async ({ request, locals, params }) => {
		const form = await superValidate(request, flashcardSchema);

		// Convenient validation check:
		if (!form.valid) return fail(400, { form });

		try {
			// Create user
			await locals.pb.collection('flashcard').create({
				name: form.data.name,
				meaning: form.data.meaning,
				romanji: form.data.romanji,
				type: form.data.type,
				flashcards_id: params.slug,
				notes: form.data.notes
			});
		} catch (e) {
			form.errors.name = ['Flashcard name is already taken.'];
			console.log(e);
		}

		return { form };
	},
	delete: async ({ request, locals }) => {
		const form = await superValidate(request, flashcardSchema);

		// Convenient validation check:
		if (!form.valid) return fail(400, { form });

		try {
			// Create user
			await locals.pb.collection('flashcard').delete(form.data.id);
		} catch (_) {
			form.errors.name = ['Flashcard name is already taken.'];
		}

		return { form };
	},
	edit: async ({ request, locals }) => {
		const form = await superValidate(request, flashcardSchema);

		// Convenient validation check:
		if (!form.valid) return fail(400, { form });

		try {
			// Create user
			await locals.pb.collection('flashcard').update(form.data.id, {
				name: form.data.name,
				meaning: form.data.meaning,
				romanji: form.data.romanji,
				type: form.data.type,
				notes: form.data.notes
			});
		} catch (_) {
			form.errors.name = ['Flashcard name is already taken.'];
		}

		return { form };
	}
};
