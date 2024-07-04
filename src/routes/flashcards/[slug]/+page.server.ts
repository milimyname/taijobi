import { countKanji } from '$lib/utils';
import { classifyWord } from '$lib/utils/flashcard';
import { flashcardSchema } from '$lib/utils/zodSchema';
import { fail } from '@sveltejs/kit';
import type PocketBase from 'pocketbase';
import { superValidate, setError } from 'sveltekit-superforms';
import { zod } from 'sveltekit-superforms/adapters';
import { isKanji } from 'wanakana';

export const load = async () => {
	return {
		form: await superValidate(zod(flashcardSchema)),
	};
};

async function updateKanjiCount(pb: PocketBase, slug: string) {
	try {
		// Get all flashcards in the box
		const flashcards = await pb.collection('flashcard').getFullList({
			filter: `flashcardBox = "${slug}"`,
		});

		// Update the flashcard box
		await pb.collection('flashcardBoxes').update(slug, {
			kanjiCount: flashcards.reduce((acc, flashcard) => acc + countKanji(flashcard.name), 0),
		});
	} catch (e) {
		console.log('error', e);
	}
}

export const actions = {
	add: async ({ request, locals, params }) => {
		const form = await superValidate(request, zod(flashcardSchema));

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
			// Create flashcard
			const name = form.data.name
				.replace(/\/.*?\//g, '')
				.replace(/'/g, '')
				.trim();

			await locals.pb.collection('flashcard').create({
				name,
				meaning: form.data.meaning,
				romanji: form.data.romanji,
				furigana: form.data.name,
				type: form.data.type,
				partOfSpeech: classifyWord(name),
				notes: form.data.notes,
				flashcardBox: params.slug,
			});
		} catch (e) {
			return setError(form, 'name', 'Flashcard name is already taken.');
		}

		// Update the flashcard box
		await updateKanjiCount(locals.pb, params.slug);

		return { form };
	},
	delete: async ({ request, locals, params }) => {
		const form = await superValidate(request, zod(flashcardSchema));

		// Convenient validation check:
		if (!form.valid || !form.data.id) return fail(400, { form });

		try {
			// Delete the flashcard
			await locals.pb.collection('flashcard').delete(form.data.id);
		} catch (_) {
			return setError(form, 'name', 'Flashcard cannot be deleted now.');
		}

		// Update the flashcard box
		await updateKanjiCount(locals.pb, params.slug);

		return { form };
	},
	update: async ({ request, locals, params }) => {
		const form = await superValidate(request, zod(flashcardSchema));

		// Convenient validation check:
		if (!form.valid || !form.data.id) return fail(400, { form });

		// Check if name is only one kanji letter
		if (form.data.type === 'kanji' && form.data.name.length !== 1)
			return setError(form, 'name', 'Flashcard name must be one kanji.');

		try {
			// Update the flashcard
			const name = form.data.name.replace(/ ?\/.*?\/ ?/g, '').trim();
			await locals.pb.collection('flashcard').update(form.data.id, {
				name,
				meaning: form.data.meaning,
				romanji: form.data.romanji || '',
				furigana: form.data.name,
				partOfSpeech: classifyWord(name),
				type: form.data.type,
				notes: form.data.notes || '',
			});
		} catch (_) {
			return setError(form, 'name', 'Flashcard cannot be edited now.');
		}

		// Update the flashcard box
		await updateKanjiCount(locals.pb, params.slug);

		return { form };
	},
};
