import Kuroshiro from '@sglkc/kuroshiro';
import KuromojiAnalyzer from '@sglkc/kuroshiro-analyzer-kuromoji';

const kuroshiro = new Kuroshiro();

let kuroshiroInitialized = false;

if (!kuroshiroInitialized) {
	await kuroshiro.init(new KuromojiAnalyzer());
	kuroshiroInitialized = true;
}

export { kuroshiro };
