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
