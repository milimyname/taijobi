import { writable } from 'svelte/store';
import type { FlashcardType } from '$lib/utils/ambient';
import { kanji } from '$lib/static/kanji';
import { hiragana } from '$lib/static/hiragana';
import { katakana } from '$lib/static/katakana';

export const showNav = writable(false);
export const showAppNav = writable(false);
export const isLongPress = writable(false);
export const animateSVG = writable(true);
export const showProgressSlider = writable(false);
export const strokeColor = writable('#000000');
export const innerWidthStore = writable(0);
export const innerHeightStore = writable(0);
export const lastPoint = writable({ x: 0, y: 0 });
export const clickedAddFlashcardCollection = writable(false);
export const currentFlashcardCollectionId = writable('');
export const currentBoxId = writable('');
export const clickedEditFlashcard = writable(false);
export const clickedAddFlahcardBox = writable(false);
export const clickedFeedback = writable(false);
export const clickedQuizForm = writable(false);
export const clickedKanjiForm = writable(false);
export const clickedFlashcardForm = writable(false);
export const skippedFlashcard = writable(false);
export const showCollections = writable(false);
export const clickedReport = writable(false);
export const flashcardsBoxType = writable('');
export const selectedKanjiGrade = writable('0');
export const maxFlashcards = writable('');
export const currentFlashcard = writable('');
export const currentIndexStore = writable<number>();
export const showLetterDrawing = writable(false);
export const selectQuizItemsForm = writable(false);
export const swapFlashcards = writable(false);
export const selectedQuizItems = writable<string[]>([]);
export const flashcardBoxes = writable<
	{
		id: string;
		name: string;
	}[]
>([]);
export const currentFlashcardTypeStore = writable('');
export const canIdrawMultipleTimes = writable(false);

export const hiraganaStore = writable(Object.keys(hiragana));
export const katakanaStore = writable(Object.keys(katakana));

// Get only keys from the kanji object
export const kanjiStore = writable(Object.keys(kanji));

export const searchedWordStore = writable<FlashcardType>(); // Use KanjiInfo as the value type
export const openSearch = writable(false);

// Get the length of the kanji store
let getKanjiLength = 0;
kanjiStore.subscribe((value) => (getKanjiLength = value.length));

export const kanjiLength = writable(getKanjiLength);
export const searchKanji = writable('');
export const kanjiWidthMulitplier = writable(100 / getKanjiLength);

export const currentLetter = writable('');
export const progressSlider = writable(1);
export const currentAlphabet = writable('');
export const uploadingProfilePic = writable(false);

export const startRangeQuizForm = writable('1');
export const endRangeQuizForm = writable('10');

/*







































































































































































































*/
