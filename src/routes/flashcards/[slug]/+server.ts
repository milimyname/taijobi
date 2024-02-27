import Kuroshiro from '@sglkc/kuroshiro';
import KuromojiAnalyzer from '@sglkc/kuroshiro-analyzer-kuromoji';
import { convertToRubyTag } from '$lib/utils/actions.js';
import { isHiragana } from 'wanakana';
import type { RecordModel } from 'pocketbase';
import { json, type RequestHandler } from '@sveltejs/kit';

const kuroshiro = new Kuroshiro();

let kuroshiroInitialized = false;

if (!kuroshiroInitialized) {
	await kuroshiro.init(new KuromojiAnalyzer());
	kuroshiroInitialized = true;
}

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

export const GET: RequestHandler = async ({ locals, params }) => {
	const flashcards = await locals.pb.collection('flashcard').getFullList({
		filter: `flashcardBox = "${params.slug}"`,
		fields: `id, name, meaning, romanji, furigana, type, notes`
	});

	const processeFlashcards = await Promise.all(
		flashcards.map((card: RecordModel) => processFurigana(card, kuroshiro))
	);

	return json({
		flashcards: processeFlashcards
	});
};

export const POST: RequestHandler = async ({ locals, params }) => {
	try {
		console.time('searchFlashcards');

		const flashcardCollections = await locals.pb.collection('flashcardCollections').getFullList({
			filter: `userId = "${locals.pb.authStore.model?.id}" || type = "original"`,
			expand: 'flashcardBoxes'
		});

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
		const flashcards = await locals.pb.collection('flashcard').getList(1, 20, {
			filter: locals.pb.filter(finalFilter, {
				search: params.slug
			})
		});

		console.timeEnd('searchFlashcards');

		return json({ flashcards: flashcards.items });
	} catch (error) {
		console.error(error);
		return json({ error });
	}
};
