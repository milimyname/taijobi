import { superValidate, setError } from 'sveltekit-superforms';
import { fail } from '@sveltejs/kit';
import { flashcardSchema } from '$lib/utils/zodSchema';
import { isKanji } from 'wanakana';
import { zod } from 'sveltekit-superforms/adapters';

export const load = async () => {
	return {
		form: await superValidate(zod(flashcardSchema))
	};
};

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
			// Create user
			await locals.pb.collection('flashcard').create({
				name: form.data.name
					.replace(/\/.*?\//g, '')
					.replace(/'/g, '')
					.trim(),
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
		const form = await superValidate(request, zod(flashcardSchema));

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
		const form = await superValidate(request, zod(flashcardSchema));

		// Convenient validation check:
		if (!form.valid || !form.data.id) return fail(400, { form });

		// Check if name is only one kanji letter
		if (form.data.type === 'kanji' && form.data.name.length !== 1)
			return setError(form, 'name', 'Flashcard name must be one kanji.');

		try {
			// Create user
			await locals.pb.collection('flashcard').update(form.data.id, {
				name: form.data.name.replace(/ ?\/.*?\/ ?/g, '').trim(),
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
