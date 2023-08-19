import type { PageServerLoad } from './$types';
import { superValidate } from 'sveltekit-superforms/server';
import { fail } from '@sveltejs/kit';
import { flashCard } from '$lib/utils/zodSchema';

export const load = (async ({ locals }) => {
	const form = await superValidate(flashCard);

	// Get all the flashcards
	const flashcards = await locals.pb.collection('flashcards').getFullList({
		sort: '+created'
	});

	return { form, flashcards: structuredClone(flashcards) };
}) satisfies PageServerLoad;

export const actions = {
	default: async ({ request, locals }) => {
		const form = await superValidate(request, flashCard);

		// Convenient validation check:
		if (!form.valid) return fail(400, { form });

		// Check if the card already exists
		let card;
		try {
			// Remove the word from db
			card = await locals.pb.collection('flashcards').getFirstListItem(`word="${form.data.word}"`);

			await locals.pb.collection('flashcards').delete(card.id);
		} catch (e) {
			// Create a new flash card
			await locals.pb.collection('flashcards').create(form.data);
		}

		return { form };
	}
};
