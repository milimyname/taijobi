import { superValidate } from 'sveltekit-superforms/server';
import { fail } from '@sveltejs/kit';
import { flashcardSchema } from '$lib/utils/zodSchema';
import Kuroshiro from '@sglkc/kuroshiro';
import KuromojiAnalyzer from '@sglkc/kuroshiro-analyzer-kuromoji';
import { convertToRubyTag } from '$lib/utils/actions.js';
import { isHiragana } from 'wanakana';
import type { RecordModel } from 'pocketbase';

const kuroshiro = new Kuroshiro();

let kuroshiroInitialized = false;

/** @type {import('./$types').PageServerLoad} */
export const load = async ({ locals, params }) => {
	// Get only 10 flashcards at a time

	console.time('getFirstTenFlashcards');
	const firstTenFlashcards = await locals.pb.collection('flashcard').getList(1, 10, {
		filter: `flashcardBox = "${params.slug}"`,
		fields: `id, name, meaning, romanji, furigana, type, notes`
	});

	if (!kuroshiroInitialized) {
		await kuroshiro.init(new KuromojiAnalyzer());
		kuroshiroInitialized = true;
	}

	// Process furigana in parallel
	const processeFirstTenFlashcards = await Promise.all(
		firstTenFlashcards.items.map((card) => processFurigana(card))
	);

	// Server API:
	const form = await superValidate(flashcardSchema);

	console.timeEnd('getFirstTenFlashcards');

	return {
		form,
		flashcards: processeFirstTenFlashcards,
		streamed: {
			flashcards:
				processeFirstTenFlashcards.length > 0
					? await Promise.all(
							(
								await locals.pb.collection('flashcard').getFullList({
									filter: `flashcardBox = "${params.slug}"`,
									fields: `id, name, meaning, romanji, furigana, type, notes`
								})
							)
								.slice(10)
								.map((card) => processFurigana(card))
						)
					: []
		}
	};
};

async function processFurigana(card: RecordModel) {
	// Custom furigana processing
	if (card.furigana.includes('/') && isHiragana(card.furigana[card.furigana.indexOf('/') + 1])) {
		card.customFurigana = card.furigana;
		card.furigana = convertToRubyTag(card.furigana);
	} else {
		// Kuroshiro conversion for kanji cards
		card.furigana = await kuroshiro.convert(card.name, {
			to: 'hiragana',
			mode: 'furigana'
		});
	}

	return card;
}

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
				flashcardBox: params.slug,
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
		if (!form.valid || !form.data.id) return fail(400, { form });

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
		if (!form.valid || !form.data.id) return fail(400, { form });

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
