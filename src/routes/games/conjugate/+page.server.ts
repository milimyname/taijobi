export const load = async ({ locals, parent, fetch }) => {
	// Get user id from authStore
	const { id } = locals.pb.authStore.model as { id: string };

	// Get a quiz
	// const conjugationDemoList = await locals.pb.collection('quizzes').getFullList({
	// 	filter: `userId = "${id}"`,
	// 	fields: 'name,type,maxCount,id,created,flashcardBox',
	// });

	// const conjugationList = [];

	return {
		// conjugationList,
		// quizzes,
	};
};
