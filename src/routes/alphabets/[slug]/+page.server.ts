import { redirect } from '@sveltejs/kit';
import type { PageServerLoad } from './$types';

/** @type {import('./$types').PageServerLoad} */
export const load = (async ({ locals }) => {
	if (locals.pb.authStore.isAdmin) throw redirect(303, '/');

	// Get all the collection of flashcards
	const folder_flashcards = await locals.pb.collection('flashcards').getFullList();

	const { id } = locals.pb.authStore.model;

	// Check if there is a kanji collection
	let collection_kanji = folder_flashcards.find(
		(card: { name: string; user_id: string }) => card.name === 'kanji' && card.user_id === id
	);
	// If there is no kanji collection, create one
	if (!collection_kanji)
		collection_kanji = await locals.pb.collection('flashcards').create({
			name: 'kanji',
			user_id: locals.pb.authStore.model.id,
			description: 'It is a list of saved kanji.'
		});

	// Get all flashcards
	const flashcard = await locals.pb.collection('flashcard').getFullList();

	return { flashcard: structuredClone(flashcard), kanji_id: collection_kanji.id };
}) satisfies PageServerLoad;
