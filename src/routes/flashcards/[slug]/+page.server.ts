import { superValidate, setError } from 'sveltekit-superforms/server';
import { fail } from '@sveltejs/kit';
import { flashcardSchema } from '$lib/utils/zodSchema';
import Kuroshiro from '@sglkc/kuroshiro';
import KuromojiAnalyzer from '@sglkc/kuroshiro-analyzer-kuromoji';
import { convertToRubyTag } from '$lib/utils/actions.js';
import { isHiragana } from 'wanakana';
import type { RecordModel } from 'pocketbase';
import { isKanji } from 'wanakana';

const kuroshiro = new Kuroshiro();

let kuroshiroInitialized = false;

if (!kuroshiroInitialized) {
	await kuroshiro.init(new KuromojiAnalyzer());
	kuroshiroInitialized = true;
}

/** @type {import('./$types').PageServerLoad} */
export const load = async ({ locals, params }) => {
	// Get only 10 flashcards at a time
	console.time('flashcards');
	const flashcards = await locals.pb.collection('flashcard').getFullList({
		filter: `flashcardBox = "${params.slug}"`,
		fields: `id, name, meaning, romanji, furigana, type, notes`
	});

	console.timeEnd('flashcards');

	// Process furigana in parallel
	const processeFlashcards = await Promise.all(
		flashcards.map((card: RecordModel) => processFurigana(card))
	);

	return {
		form: await superValidate(flashcardSchema),
		flashcards: processeFlashcards
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

		if (form.data.type === 'kanji') {
			// Check if name is only kanji
			if (!isKanji(form.data.name) && form.data.name.length !== 1)
				return setError(form, 'name', 'Flashcard name must be only one kanji.');

			// Check if name is only one kanji letter
			if (form.data.name.length !== 1)
				return setError(form, 'name', 'Flashcard name must be one kanji.');
		}

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
			return setError(form, 'name', 'Flashcard name is already taken.');
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
			return setError(form, 'name', 'Flashcard cannot be deleted now.');
		}

		return { form };
	},
	update: async ({ request, locals }) => {
		const form = await superValidate(request, flashcardSchema);

		// Convenient validation check:
		if (!form.valid || !form.data.id) return fail(400, { form });

		if (form.data.type === 'kanji') {
			// Check if name is only kanji
			if (!isKanji(form.data.name)) return setError(form, 'name', 'Flashcard name must be kanji.');

			// Check if name is only one kanji letter
			if (form.data.name.length !== 1)
				return setError(form, 'name', 'Flashcard name must be one kanji.');
		}

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
			return setError(form, 'name', 'Flashcard cannot be edited now.');
		}

		return { form };
	}
};
