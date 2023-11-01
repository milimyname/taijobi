/** @type {import('./$types').PageServerLoad} */
export const load = async ({ locals }) => {
	// Get user id from authStore
	const { id } = locals.pb.authStore.model as { id: string };
	// Get quizzes by user id
	const quizzes = await locals.pb.collection('quizProgress').getFullList({
		filter: `userId = "${id}"`
	});

	// Extract completions (assuming score represents completions)
	const completions = {};

	quizzes.forEach((quiz) => {
		const month = new Date(quiz.created).toLocaleString('default', {
			month: 'short'
		});

		if (!completions[month]) completions[month] = 0;

		// Use a ternary operator to increase the count if quiz.completed is true
		completions[month] += quiz.completed ? 1 : 0;
	});

	return {
		quizzes,
		completions: completions,
		id
	};
};
