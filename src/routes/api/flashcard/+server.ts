import { convertToRubyTag } from '$lib/utils/actions.js';
import { isHiragana } from 'wanakana';
import type { RecordModel } from 'pocketbase';
import { json, type RequestHandler } from '@sveltejs/kit';
import { kanji } from '$lib/static/kanji';
import { kuroshiro } from '$lib/server/kuroshiro';

async function processFurigana(card: RecordModel, kuroshiro: Kuroshiro) {
	// Custom furigana processing
	if (card.furigana.includes('/') && isHiragana(card.furigana[card.furigana.indexOf('/') + 1])) {
		card.customFurigana = card.furigana;
		card.furigana = convertToRubyTag(card.furigana);
	} else {
		// Kuroshiro conversion for kanji cards
		card.furigana = await kuroshiro.convert(card.name, {
			to: 'hiragana',
			mode: 'furigana'
		});
	}

	return card;
}

export const GET: RequestHandler = async ({ locals, url }) => {
	// Get id slug
	const flashcardBoxId = url.searchParams.get('id');

	// Check if id exists
	if (!flashcardBoxId) return json({ error: 'Flashcard box not found' });

	const flashcards = await locals.pb.collection('flashcard').getFullList({
		filter: `flashcardBox = "${flashcardBoxId}"`,
		fields: `id, name, meaning, romanji, furigana, type, notes`
	});

	const processedFlashcards = await Promise.all(
		flashcards.map((card: RecordModel) => processFurigana(card, kuroshiro))
	);

	return json({
		flashcards: processedFlashcards
	});
};

// Get kanji meaning or name by slug
function getKanjiBySlug(slug: string) {
	const foundKanji = Object.entries(kanji).find(
		([key, value]) => value.meaning.includes(slug) || key.includes(slug)
	);

	return foundKanji && { name: foundKanji[0], meaning: foundKanji[1].meaning };
}

// Get the flashcard box by slug and return the flashcards for command component
export const POST: RequestHandler = async ({ locals, request }) => {
	try {
		// Check if the user is authenticated
		if (!locals.pb.authStore.model) return json({ error: 'User not authenticated' });

		const { search } = await request.json();

		// If search is not provided, return an error
		if (!search) return json({ error: 'Search is required' });

		console.time('searchFlashcards');

		// Fetch flashcard collections
		const flashcardCollections = await locals.pb.collection('flashcardCollections').getFullList({
			filter: `userId = "${locals.pb.authStore.model?.id}" || type = "original"`,
			expand: 'flashcardBoxes'
		});

		// Get all flashcard box IDs
		const flashcardBoxIds = flashcardCollections.flatMap((collection) =>
			collection.flashcardBoxes.map((id: string) => id)
		);

		// Deduplicate the IDs if necessary
		const uniqueFlashcardBoxIds = [...new Set(flashcardBoxIds)];

		// Dynamically build the OR-based filter string for multiple box IDs
		const boxIdFilter = uniqueFlashcardBoxIds.map((id) => `flashcardBox="${id}"`).join(' || ');

		// Construct the final filter with additional search criteria
		const finalFilter = `(${boxIdFilter}) && (name ~ {:search} || meaning ~ {:search})`;

		// Fetch flashcards for each flashcard box
		const flashcards = await locals.pb.collection('flashcard').getList(1, 100, {
			filter: locals.pb.filter(finalFilter, {
				search
			})
		});

		// Process the furigana for each flashcard
		const processedFlashcards = await Promise.all(
			flashcards.items.map((card: RecordModel) => processFurigana(card, kuroshiro))
		);

		// Get the kanji by slug
		const kanji = getKanjiBySlug(search);

		// If there is kanji in processed flashcards, don't add
		if (kanji) {
			const foundKanji = processedFlashcards.find((card) => card.name === kanji.name);
			if (!foundKanji) processedFlashcards.unshift(kanji);
		}

		console.timeEnd('searchFlashcards');

		return json({ flashcards: processedFlashcards });
	} catch (error) {
		console.error(error);
		return json({ error });
	}
};
