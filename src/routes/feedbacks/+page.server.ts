/** @type {import('./$types').PageServerLoad} */
export const load = async ({ locals }) => {
	let feedbacks;
	if (locals.pb.authStore.isAdmin)
		// Get all the flashcards
		feedbacks = await locals.pb.collection('feedbacks').getFullList();
	// Get all the flashcards
	else
		feedbacks = await locals.pb
			.collection('feedbacks')
			.getFullList(100, { filter: `user_id = "${locals.pb.authStore.model.id}"` });

	return { feedbacks: structuredClone(feedbacks) };
};
