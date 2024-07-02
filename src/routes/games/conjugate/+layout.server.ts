import PocketBase, { type RecordModel } from 'pocketbase';

// Create demo data for hiragana and katakana quizzes
async function createDemoData(pb: PocketBase, fetch: typeof window.fetch) {
	const firstTenFlashcards = await pb
		.collection('flashcardBoxes')
		.getFirstListItem('name = "Lesson 20"', {
			expand: 'flashcards',
			fields: 'id,name,expand',
		});

	const data = await Promise.all(
		firstTenFlashcards?.expand?.flashcards.slice(0, 10).map(async (flashcard: RecordModel) => {
			const conjugation = await fetch(`/api/conjugation`, {
				method: 'POST',
				headers: {
					'Content-Type': 'application/json',
				},
				body: JSON.stringify({ word: flashcard.name }),
			});

			return {
				id: flashcard.id,
				name: flashcard.name,
				conjugation: await conjugation.json(),
			};
		}),
	);

	return data;
}

export const load = async ({ locals, fetch }) => {
	const demoList = [
		{
			id: 'demo',
			name: 'Demo',
			type: 'verb',
			created: new Date(),
			flashcards: await createDemoData(locals.pb, fetch),
		},
	];

	if (!locals.pb.authStore.isValid)
		return {
			isLoggedIn: false,
			isAdmin: false,
			conjugationDemoList: demoList,
		};

	const user = structuredClone(locals.pb.authStore.model);
	return {
		isAdmin: user?.role.includes('admin'),
		isLoggedIn: true,
		conjugationDemoList: demoList,
	};
};
