import { superValidate } from 'sveltekit-superforms/server';
import { fail } from '@sveltejs/kit';
import { flashcardSchema } from '$lib/utils/zodSchema';
import type { PageServerLoad } from '../$types';

export const load = (async ({ locals, params }) => {
	// Get all the flashcards
	const flashcards = await locals.pb
		.collection('flashcard')
		.getFullList(100, { filter: `flashcards_id = "${params.slug}"` });

	// Server API:
	const form = await superValidate(flashcardSchema);

	return { form, flashcards: structuredClone(flashcards) };
}) satisfies PageServerLoad;

export const actions = {
	default: async ({ request, locals, params }) => {
		const form = await superValidate(request, flashcardSchema);

		// Convenient validation check:
		if (!form.valid) return fail(400, { form });

		try {
			// Create user
			await locals.pb.collection('flashcard').create({
				name: form.data.name,
				meaning: form.data.meaning,
				type: form.data.type,
				flashcards_id: params.slug
			});
		} catch (_) {
			form.errors.name = ['Name already exists'];
		}

		return { form };
	}
};
