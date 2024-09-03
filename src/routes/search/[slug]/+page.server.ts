import { kuroshiro } from '$lib/server/kuroshiro.js';
import { searchCollectionSchema } from '$lib/utils/zodSchema.js';
import { redirect } from '@sveltejs/kit';
import type { RecordModel } from 'pocketbase';
import type PocketBase from 'pocketbase';
import { fail, setError, superValidate } from 'sveltekit-superforms';
import { zod } from 'sveltekit-superforms/adapters';
import { z } from 'zod';

async function convertToFurigana(word: string) {
	return await kuroshiro.convert(word, { to: 'hiragana', mode: 'furigana' });
}

export const load = async ({ locals, params }) => {
	if (!locals.pb.authStore.isValid) redirect(401, '/login');

	const { slug } = params;

	// Redirect to home if no search query
	if (!slug) redirect(404, '/');

	try {
		const currentSearch = await locals.pb.collection('searches').getOne(slug, {
			expand: 'flashcard',
		});

		const searches = await locals.pb.collection('searches').getFullList({
			filter: `user = "${locals.pb.authStore.model?.id}"`,
			expand: 'flashcard.flashcardBox',
		});

		const flashcardCollections = await locals.pb.collection('flashcardCollections').getFullList({
			filter: `userId = "${locals.pb.authStore.model?.id}"`,
			expand: 'flashcardBoxes',
			fields: 'id,name,expand',
		});

		const flashcardsIds = searches.map((s: RecordModel) => {
			if (!s.expand?.flashcard) return null;
			return s.expand.flashcard.id;
		});

		return {
			currentSearch: {
				...currentSearch,
				expand: {
					...currentSearch.expand,
					flashcard: {
						...currentSearch.expand?.flashcard,
						furigana: await convertToFurigana(currentSearch.expand?.flashcard?.name),
					},
				},
			},
			searches,
			flashcardsIds,
			form: await superValidate(zod(searchCollectionSchema)),
			flashcardCollections: flashcardCollections.map((collection) => ({
				id: collection.id,
				name: collection.name,
				boxes: collection.expand?.flashcardBoxes.map((box: RecordModel) => ({
					id: box.id,
					name: box.name,
				})),
			})),
		};
	} catch (error) {
		console.error(error);
		throw redirect(307, '/');
	}
};

async function createCopiedFlashcards(
	pb: PocketBase,
	flashcards: z.infer<typeof searchCollectionSchema>['flashcards'],
	boxId?: string,
) {
	try {
		return await Promise.all(
			flashcards.map((flashcard) =>
				pb.collection('flashcard').create(
					{
						name: flashcard?.name,
						meaning: flashcard?.meaning,
						type: flashcard?.type,
						romaji: flashcard?.romaji,
						furigana: flashcard?.furigana,
						partOfSpeech: flashcard?.partOfSpeech,
						copiedFlashcard: flashcard?.id,
						flashcardBox: boxId,
					},
					{
						requestKey: null,
					},
				),
			),
		);
	} catch (error) {
		console.error(error);
	}
}

export const actions = {
	add: async ({ request, locals }) => {
		const form = await superValidate(request, zod(searchCollectionSchema));

		// Convenient validation check:
		if (!form.valid) return fail(400, { form });

		if (!form.data.flashcards) return setError(form, 'collectionId', 'Please select flashcards');

		if (form.data.collectionId === 'new-collection') {
			try {
				const newCollection = await locals.pb.collection('flashcardCollections').create({
					name: form.data.collectionName,
					userId: locals?.pb.authStore.model?.id,
					type: 'custom',
				});

				await locals.pb.collection('users').update(locals?.pb.authStore.model?.id, {
					'flashcardCollections+': newCollection.id,
				});

				const newBox = await locals.pb.collection('flashcardBoxes').create({
					name: form.data.boxName,
					flashcardCollection: newCollection.id,
					userId: locals?.pb.authStore.model?.id,
				});

				const newFlashcards = await createCopiedFlashcards(
					locals.pb,
					form.data.flashcards,
					newBox?.id,
				);

				await locals.pb.collection('flashcardCollections').update(newCollection.id, {
					'flashcardBoxes+': newBox.id,
				});

				await locals.pb.collection('flashcardBoxes').update(newBox.id, {
					'flashcards+': newFlashcards?.map((flashcard) => flashcard.id),
				});

				form.data.collectionId = newCollection.id;
				form.data.boxId = newBox.id;

				return { form };
			} catch (error) {
				return setError(form, 'collectionId', 'Try again');
			}
		}

		if (form.data.collectionId !== 'new-collection' && form.data.boxId === 'new-box') {
			try {
				const newFlashcards = await createCopiedFlashcards(locals.pb, form.data.flashcards);

				const newBox = await locals.pb.collection('flashcardBoxes').create({
					name: form.data.boxName,
					flashcardCollection: form.data.collectionId,
					userId: locals?.pb.authStore.model?.id,
					'flashcards+': newFlashcards?.map((flashcard) => flashcard.id),
				});

				form.data.boxId = newBox.id;

				return { form };
			} catch (error) {
				return setError(form, 'boxId', 'Try again');
			}
		}

		// If collection id and box id are not new, then just add the flashcards to the box
		if (form.data.collectionId !== 'new-collection' && form.data.boxId !== 'new-box') {
			try {
				const newFlashcards = await createCopiedFlashcards(
					locals.pb,
					form.data.flashcards,
					form.data.boxId,
				);

				await locals.pb.collection('flashcardBoxes').update(form.data.boxId, {
					'flashcards+': newFlashcards?.map((flashcard) => flashcard.id),
				});

				return { form };
			} catch (error) {
				return setError(form, 'boxId', 'Try again');
			}
		}

		return { form };
	},
};
