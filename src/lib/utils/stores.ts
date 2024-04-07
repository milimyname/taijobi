import { writable } from 'svelte/store';
import type { FlashcardType } from '$lib/utils/ambient';
import { kanji } from '$lib/static/kanji';

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

export const hiraganaStore = writable([
	'あ',
	'い',
	'う',
	'え',
	'お',
	'か',
	'き',
	'く',
	'け',
	'こ',
	'さ',
	'し',
	'す',
	'せ',
	'そ',
	'た',
	'ち',
	'つ',
	'て',
	'と',
	'な',
	'に',
	'ぬ',
	'ね',
	'の',
	'は',
	'ひ',
	'ふ',
	'へ',
	'ほ',
	'ま',
	'み',
	'む',
	'め',
	'も',
	'や',
	'ゆ',
	'よ',
	'ら',
	'り',
	'る',
	'れ',
	'ろ',
	'わ',
	'を',
	'ん',
	'が',
	'ぎ',
	'ぐ',
	'げ',
	'ご',
	'ざ',
	'じ',
	'ず',
	'ぜ',
	'ぞ',
	'だ',
	'ぢ',
	'づ',
	'で',
	'ど',
	'ば',
	'び',
	'ぶ',
	'べ',
	'ぼ',
	'ぱ',
	'ぴ',
	'ぷ',
	'ぺ',
	'ぽ',
	'ゃ',
	'ゅ',
	'ょ'
]);
export const katakanaStore = writable([
	'ア',
	'イ',
	'ウ',
	'エ',
	'オ',
	'カ',
	'キ',
	'ク',
	'ケ',
	'コ',
	'サ',
	'シ',
	'ス',
	'セ',
	'ソ',
	'タ',
	'チ',
	'ツ',
	'テ',
	'ト',
	'ナ',
	'ニ',
	'ヌ',
	'ネ',
	'ノ',
	'ハ',
	'ヒ',
	'フ',
	'ヘ',
	'ホ',
	'マ',
	'ミ',
	'ム',
	'メ',
	'モ',
	'ヤ',
	'ユ',
	'ヨ',
	'ラ',
	'リ',
	'ル',
	'レ',
	'ロ',
	'ワ',
	'ヲ',
	'ン',
	'ー',
	'ガ',
	'ギ',
	'グ',
	'ゲ',
	'ゴ',
	'ザ',
	'ジ',
	'ズ',
	'ゼ',
	'ゾ',
	'ダ',
	'ヂ',
	'ヅ',
	'デ',
	'ド',
	'バ',
	'ビ',
	'ブ',
	'ベ',
	'ボ',
	'パ',
	'ピ',
	'プ',
	'ペ',
	'ポ',
	'ヴ',
	'ァ',
	'ィ',
	'ゥ',
	'ェ',
	'ォ',
	'ャ',
	'ュ',
	'ョ'
]);

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

/*







































































































































































































*/
