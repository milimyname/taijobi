import { superValidate } from 'sveltekit-superforms/server';
import { fail } from '@sveltejs/kit';
import { flashcardSchema } from '$lib/utils/zodSchema';
import Kuroshiro from '@sglkc/kuroshiro';
import KuromojiAnalyzer from '@sglkc/kuroshiro-analyzer-kuromoji';
import { convertToRubyTag } from '$lib/utils/actions.js';
import { isHiragana } from 'wanakana';

const kuroshiro = new Kuroshiro();

let kuroshiroInitialized = false; // Add this flag to track initialization

/** @type {import('./$types').PageServerLoad} */
export const load = async ({ locals, params }) => {
	if (!kuroshiroInitialized) {
		await kuroshiro.init(new KuromojiAnalyzer());
		kuroshiroInitialized = true;
	}

	// Get all the flashcards
	const flashcards = await locals.pb.collection('flashcard').getFullList({
		filter: `flashcardsId = "${params.slug}"`,
		fields: `id, name, meaning, romanji, furigana, type, notes`
	});

	// Check if they are kanji type
	const kanjiFlashcards = flashcards.filter((card) => card.type === 'kanji');

	if (kanjiFlashcards.length > 0) {
		// Server API:
		const form = await superValidate(flashcardSchema);

		return {
			form,
			flashcards: structuredClone(flashcards)
		};
	}

	// Add furigana to the flashcards
	const furiganaPromises = structuredClone(flashcards);

	furiganaPromises.map(async (card) => {
		if (card.furigana.includes('/') && isHiragana(card.furigana[card.furigana.indexOf('/') + 1])) {
			card.customFurigana = card.furigana;
			card.furigana = convertToRubyTag(card.furigana);
			return;
		}

		card.furigana = await kuroshiro.convert(card.name, {
			to: 'hiragana',
			mode: 'furigana'
		});
	});

	// Wait for all the Promises to resolve
	const furiganas = await Promise.all(furiganaPromises);

	// Server API:
	const form = await superValidate(flashcardSchema);

	return {
		form,
		flashcards: furiganas
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
				name: form.data.name.replace(/\/.*?\//g, '').replace(/'/g, ''),
				meaning: form.data.meaning,
				romanji: form.data.romanji,
				furigana: form.data.name,
				type: form.data.type,
				flashcardsId: params.slug,
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

		console.log({
			data: form.data
		});

		try {
			// Create user
			await locals.pb.collection('flashcard').update(form.data.id, {
				name: form.data.name.replace(/ ?\/.*?\/ ?/g, ''),
				meaning: form.data.meaning,
				romanji: form.data.romanji || '',
				furigana: form.data.name,
				type: form.data.type,
				notes: form.data.notes || ''
			});
		} catch (_) {
			form.errors.name = ['Flashcard name is already taken.'];
		}

		return { form };
	}
};
