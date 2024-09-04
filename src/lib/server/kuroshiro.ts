import Kuroshiro from '@sglkc/kuroshiro';
import KuromojiAnalyzer from '@sglkc/kuroshiro-analyzer-kuromoji';

const kuroshiro = new Kuroshiro();

let kuroshiroInitialized = false;

if (!kuroshiroInitialized) {
	await kuroshiro.init(new KuromojiAnalyzer());
	kuroshiroInitialized = true;
}

async function convertToFurigana(word: string) {
	return await kuroshiro.convert(word, { to: 'hiragana', mode: 'furigana' });
}

async function convertToKana(word: string) {
	return await kuroshiro.convert(word, { to: 'hiragana', mode: 'normal' });
}

export { kuroshiro, convertToFurigana, convertToKana };
