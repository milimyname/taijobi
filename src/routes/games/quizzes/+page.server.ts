// Create fake data for hiragana and katakana quizzes
function createFakeData() {
	return {
		collectionId: '-',
		collectionName: '-',
		created: '-',
		flashcardBox: '=',

		maxCount: 46,
		score: 0,
		timeLimit: false,
		choice: '4',
		type: 'name',
		updated: '2',
		userId: '-'
	};
}

/** @type {import('./$types').PageServerLoad} */
export const load = async ({ locals, parent }) => {
	const { isLoggedIn } = await parent();

	if (!isLoggedIn)
		return {
			quizzes: [
				{
					name: 'ひらがな',
					id: 'hiragana',
					...createFakeData()
				},
				{
					name: 'カタカナ',
					id: 'katakana',
					...createFakeData()
				}
			]
		};

	// Get user id from authStore
	const { id } = locals.pb.authStore.model as { id: string };
	// Get a quiz
	let quizzes = await locals.pb.collection('quizzes').getFullList({
		filter: `userId = "${id}"`,
		fields: 'name,type,maxCount,id,created,flashcardBox'
	});

	// Add hiragana and katakana quizzes

	quizzes = [
		{
			name: 'ひらがな',
			id: 'hiragana',
			...createFakeData()
		},
		{
			name: 'カタカナ',
			id: 'katakana',
			...createFakeData()
		},
		...quizzes
	];

	return {
		quizzes
	};
};
