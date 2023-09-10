/** @type {import('./$types').PageServerLoad} */
export const load = async ({ locals }) => {
	let feedbacks;

	const { role, id } = locals.pb.authStore.model;

	if (role.includes('admin'))
		// Get all the flashcards
		feedbacks = await locals.pb.collection('feedbacks').getFullList();
	// Get all the flashcards
	else
		feedbacks = await locals.pb
			.collection('feedbacks')
			.getFullList(100, { filter: `user_id = "${id}"` });

	return { feedbacks: structuredClone(feedbacks) };
};
