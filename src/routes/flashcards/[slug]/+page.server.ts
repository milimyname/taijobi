import { superValidate } from 'sveltekit-superforms/server';
import { fail } from '@sveltejs/kit';
import { flashcardSchema } from '$lib/utils/zodSchema';
import type { PageServerLoad } from '../$types';

// Disable server-side rendering:
export const ssr = false;

/** @type {import('./$types').PageServerLoad} */
export const load = (async ({ locals, params }) => {
	// Get all the flashcards
	const flashcards = await locals.pb
		.collection('flashcard')
		.getFullList(100, { filter: `flashcards_id = "${params.slug}"` });

	// Server API:
	const form = await superValidate(flashcardSchema);

	return { form, flashcards: structuredClone(flashcards) };
}) satisfies PageServerLoad;

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
				type: form.data.type,
				notes: form.data.notes
			});
		} catch (_) {
			form.errors.name = ['Flashcard name is already taken.'];
		}

		return { form };
	}
};
