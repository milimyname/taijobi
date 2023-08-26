import type { PageServerLoad } from './$types';
import { superValidate } from 'sveltekit-superforms/server';
import { fail, redirect } from '@sveltejs/kit';
import { flashcardsSchema } from '$lib/utils/zodSchema';

export const load = (async ({ locals }) => {
	// Get user_id from authStore
	const { id } = await locals.pb.authStore.model;

	// Get all the flashcards
	const flashcards = await locals.pb
		.collection('flashcards')
		.getFullList(100, { filter: `user_id = "${id}"` });

	// Server API:
	const form = await superValidate(flashcardsSchema);

	return { form, flashcards: structuredClone(flashcards) };
}) satisfies PageServerLoad;

export const actions = {
	default: async ({ request, locals }) => {
		const form = await superValidate(request, flashcardsSchema);

		// Convenient validation check:
		if (!form.valid) return fail(400, { form });

		// Get user_id from authStore
		const { id } = await locals.pb.authStore.model;

		let folder_flashcards;

		try {
			// Create user
			folder_flashcards = await locals.pb
				.collection('flashcards')
				.create({ name: form.data.name, description: form.data.description, user_id: id });
		} catch (_) {
			form.errors.name = ['Name already exists'];
			return { form };
		}

		throw redirect(303, `/flashcards/${folder_flashcards.id}`);
	}
};