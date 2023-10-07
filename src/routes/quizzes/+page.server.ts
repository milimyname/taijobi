/** @type {import('./$types').PageServerLoad} */
export const load = async ({ locals }) => {
	// Get user id from authStore
	const { id } = locals.pb.authStore.model as { id: string };
	// Get a quiz
	const quizzes = await locals.pb.collection('quizzes').getFullList({
		filter: `userId = "${id}"`
	});

	// Server API:

	return {
		quizzes
	};
};
