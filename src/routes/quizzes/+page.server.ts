/** @type {import('./$types').PageServerLoad} */
export const load = async ({ locals }) => {
	// Get user id from authStore
	const { id } = locals.pb.authStore.model as { id: string };
	// Get a quiz
	let quizzes = await locals.pb.collection('quizzes').getFullList({
		filter: `userId = "${id}"`,
		fields: 'name,type,maxCount,id'
	});

	// Add hiragana and katakana quizzes
	const fakeData = {
		collectionId: '-',
		collectionName: '-',
		created: '-',
		flashcardsId: '=',

		maxCount: 46,
		score: 0,
		timeLimit: false,
		choice: '4',
		type: 'name',
		updated: '2',
		userId: '-'
	};

	quizzes = [
		{
			name: 'ひらがな',
			id: 'hiragana',
			...fakeData
		},
		{
			name: 'カタカナ',
			id: 'katakana',
			...fakeData
		},
		...quizzes
	];

	return {
		quizzes
	};
};
