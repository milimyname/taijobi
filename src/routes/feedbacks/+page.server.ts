/** @type {import('./$types').PageLoad} */
export const load = async ({ locals }) => {
	// Get user_id from authStore
	const { id, username } = await locals.pb.authStore.model;

	let feedbacks;
	if (username === 'users56993')
		// Get all the flashcards
		feedbacks = await locals.pb.collection('feedbacks').getFullList();
	// Get all the flashcards
	else
		feedbacks = await locals.pb
			.collection('feedbacks')
			.getFullList(100, { filter: `user_id = "${id}"` });

	return { feedbacks: structuredClone(feedbacks) };
};
