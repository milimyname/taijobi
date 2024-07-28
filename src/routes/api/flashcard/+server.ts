import { convertToFurigana } from '$lib/server/kuroshiro';
import { kanji } from '$lib/static/kanji';
import { convertToRubyTag } from '$lib/utils/actions.js';
import { getFlashcardPartOfSpeech, getFlashcardType } from '$lib/utils/flashcard';
import { json, type RequestHandler } from '@sveltejs/kit';
import type { RecordModel } from 'pocketbase';
import { isHiragana, isRomaji } from 'wanakana';

async function processFurigana(card: RecordModel) {
	// Custom furigana processing
	if (card.furigana.includes('/') && isHiragana(card.furigana[card.furigana.indexOf('/') + 1])) {
		card.customFurigana = card.furigana;
		card.furigana = convertToRubyTag(card.furigana);
	} else {
		// Kuroshiro conversion for kanji cards
		card.furigana = await convertToFurigana(card.name);
	}

	return card;
}

export const GET: RequestHandler = async ({ locals, url }) => {
	// Get id slug
	const flashcardBoxId = url.searchParams.get('id');

	// Check if id exists
	if (!flashcardBoxId) return json({ error: 'Flashcard box not found' });

	// Check if flashcardBoxId exists in db
	try {
		await locals.pb.collection('flashcardBoxes').getFirstListItem(`id = "${flashcardBoxId}"`);
	} catch (e) {
		return json({ error: 'Flashcard box not found' });
	}

	const flashcards = await locals.pb.collection('flashcard').getFullList({
		filter: `flashcardBox = "${flashcardBoxId}"`,
		fields: `id, name, meaning, romanji, furigana, type, notes`,
	});

	const processedFlashcards = await Promise.all(
		flashcards.map((card: RecordModel) => processFurigana(card)),
	);

	return json({
		flashcards: processedFlashcards,
	});
};

// Get kanji meaning or name by slug
function getKanjiBySlug(slug: string) {
	const foundKanji = Object.entries(kanji).find(
		([key, value]) => value.meaning.includes(slug) || key.includes(slug),
	);

	return foundKanji && { name: foundKanji[0], meaning: foundKanji[1].meaning };
}

// Get the flashcard box by slug and return the flashcards for command component
export const POST: RequestHandler = async ({ locals, request, fetch }) => {
	try {
		// Check if the user is authenticated
		if (!locals.pb.authStore.model) return json({ error: 'User not authenticated' });

		const { search, type } = await request.json();

		// If search is not provided, return an error
		if (!search) return json({ error: 'Queries are missing' });

		if (type === 'search') {
			const res = await fetch('/api/openai', {
				method: 'POST',
				headers: {
					'Content-Type': 'application/json',
				},
				body: JSON.stringify({ input: search, type: 'search' }),
			});

			const data = await res.json();

			if (data.meaning === 'Does not exist') return json({ error: 'Flashcard not found' });

			const type = getFlashcardType(data.type);
			const partOfSpeech = getFlashcardPartOfSpeech(data.partOfSpeech);
			const meaning = isRomaji(data.name) ? data.name : data.meaning;
			const furigana = isRomaji(data.furigana) ? '' : data.furigana;

			// Create a flashcard if the search is a kanji
			let flashcard = await locals.pb.collection('flashcard').create({
				name: isRomaji(data.name) ? data.meaning : data.name,
				meaning: meaning.includes(';') ? meaning.split(';').join(',') : meaning,
				type,
				romanji: data.romanji,
				furigana,
				partOfSpeech,
			});

			const newSearch = await locals.pb.collection('searches').create({
				flashcard: flashcard.id,
				user: locals.pb.authStore.model.id,
				searchQuery: search,
			});

			flashcard = await locals.pb.collection('flashcard').update(flashcard.id, {
				'searches+': newSearch.id,
			});

			return json({ flashcard });
		}

		console.time('searchFlashcards');

		// Fetch flashcard collections
		const flashcardCollections = await locals.pb.collection('flashcardCollections').getFullList({
			filter: `userId = "${locals.pb.authStore.model?.id}" || type = "original"`,
			expand: 'flashcardBoxes',
		});

		// Get all flashcard box IDs
		const flashcardBoxIds = flashcardCollections.flatMap((collection) =>
			collection.flashcardBoxes.map((id: string) => id),
		);
		// Deduplicate the IDs if necessary and add an empty string for the unassigned flashcards
		const uniqueFlashcardBoxIds = [...new Set(flashcardBoxIds), ''];

		// Dynamically build the OR-based filter string for multiple box IDs
		const boxIdFilter = uniqueFlashcardBoxIds.map((id) => `flashcardBox="${id}"`).join(' || ');

		// Construct the final filter with additional search criteria
		const finalFilter = `(${boxIdFilter}) && (name ~ {:search} || meaning ~ {:search})`;

		// Fetch flashcards for each flashcard box
		const flashcards = await locals.pb.collection('flashcard').getList(1, 100, {
			filter: locals.pb.filter(finalFilter, {
				search,
			}),
			expand: 'flashcardBox',
			fields: `id, name, meaning, type, furigana, flashcardBox, expand.flashcardBox.name`,
		});

		// Process the furigana for each flashcard
		const processedFlashcards = await Promise.all(
			flashcards.items.map((card: RecordModel) => processFurigana(card, kuroshiro)),
		);

		// Get the kanji by slug
		const kanji = getKanjiBySlug(search);

		// If there is kanji in processed flashcards, don't add
		if (kanji) {
			const foundKanji = processedFlashcards.find((card) => card.name === kanji.name);
			if (!foundKanji) processedFlashcards.unshift(kanji);
		}

		console.timeEnd('searchFlashcards');

		if (processedFlashcards.length === 0 && type === 'find') {
			const res = await fetch('/api/openai', {
				method: 'POST',
				headers: {
					'Content-Type': 'application/json',
				},
				body: JSON.stringify({ input: search, type: 'find' }),
			});

			const data = await res.json();

			console.log(data);

			if (data.meaning === 'Does not exist') return json({ error: 'Flashcard not found' });

			const type = getFlashcardType(data.type);
			const partOfSpeech = getFlashcardPartOfSpeech(data.partOfSpeech);

			const meaning = isRomaji(data.name) ? data.name : data.meaning;
			const furigana = isRomaji(data.furigana) ? '' : data.furigana;

			// Create a flashcard if the search is a kanji
			let flashcard = await locals.pb.collection('flashcard').create({
				name: isRomaji(data.name) ? data.meaning : data.name,
				meaning: meaning.includes(';') ? meaning.split(';').join(',') : meaning,
				type,
				romanji: data.romanji,
				furigana,
				partOfSpeech,
			});

			const newSearch = await locals.pb.collection('searches').create({
				flashcard: flashcard.id,
				user: locals.pb.authStore.model.id,
				searchQuery: search,
			});

			flashcard = await locals.pb.collection('flashcard').update(flashcard.id, {
				'searches+': newSearch.id,
			});

			return json({ flashcards: newSearch });
		}

		return json({ flashcards: processedFlashcards });
	} catch (error) {
		console.error(error);
		return json({ error });
	}
};
