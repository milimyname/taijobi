import { isKana } from 'wanakana';

export function getPlainForm(verb: string): string {
	// Handle truly irregular verbs
	const irregulars: { [key: string]: string } = {
		します: 'する',
		きます: 'くる',
		いきます: 'いく', // 行きます -> 行く
		あります: 'ある',
	};

	if (irregulars[verb]) return irregulars[verb];

	// Remove 'ます' to get the stem
	const stem = verb.slice(0, -2);

	// Find the last kana in the stem
	let lastKanaIndex = -1;
	for (let i = stem.length - 1; i >= 0; i--) {
		if (isKana(stem[i])) {
			lastKanaIndex = i;
			break;
		}
	}

	const lastKana = lastKanaIndex !== -1 ? stem[lastKanaIndex] : '';

	// List of known Ichidan verbs
	const ichidanVerbs: string[] = [
		'寝ます',
		'見ます',
		'食べます',
		'起きます',
		'借ります',
		'開けます',
		'教えます',
	];

	if (ichidanVerbs.includes(verb)) {
		return stem + 'る';
	}

	// For Godan verbs ending with specific kana
	const godanConversion: { [key: string]: string } = {
		い: 'う',
		き: 'く',
		ぎ: 'ぐ',
		し: 'す',
		ち: 'つ',
		に: 'ぬ',
		ひ: 'ふ',
		び: 'ぶ',
		ぴ: 'ぷ',
		み: 'む',
		り: 'る',
	};

	if (lastKana && godanConversion[lastKana]) {
		// Replace the last kana with its 'u' equivalent
		const newKana = godanConversion[lastKana];
		return stem.slice(0, lastKanaIndex) + newKana;
	}

	// If last kana is 'え' or 'い', assume Ichidan verb
	const lastVowel = getVowelSound(lastKana);
	if (lastVowel === 'え' || lastVowel === 'い') {
		return stem + 'る';
	}

	// If no kana found and stem is a single character (kanji), assume Ichidan verb
	if (lastKanaIndex === -1 && stem.length === 1) {
		return stem + 'る';
	}

	// Fallback, return the verb as is
	return verb;
}

// Helper function to get the vowel sound of a kana
function getVowelSound(kana: string): string {
	const vowels: { [key: string]: string } = {
		あ: 'あ',
		か: 'あ',
		さ: 'あ',
		た: 'あ',
		な: 'あ',
		は: 'あ',
		ま: 'あ',
		や: 'あ',
		ら: 'あ',
		わ: 'あ',
		い: 'い',
		き: 'い',
		し: 'い',
		ち: 'い',
		に: 'い',
		ひ: 'い',
		み: 'い',
		り: 'い',
		ぎ: 'い',
		じ: 'い',
		ぢ: 'い',
		び: 'い',
		ぴ: 'い',
		う: 'う',
		く: 'う',
		す: 'う',
		つ: 'う',
		ぬ: 'う',
		ふ: 'う',
		む: 'う',
		ゆ: 'う',
		る: 'う',
		ぐ: 'う',
		ず: 'う',
		ぶ: 'う',
		ぷ: 'う',
		え: 'え',
		け: 'え',
		せ: 'え',
		て: 'え',
		ね: 'え',
		へ: 'え',
		め: 'え',
		れ: 'え',
		げ: 'え',
		ぜ: 'え',
		で: 'え',
		べ: 'え',
		ぺ: 'え',
		お: 'お',
		こ: 'お',
		そ: 'お',
		と: 'お',
		の: 'お',
		ほ: 'お',
		も: 'お',
		よ: 'お',
		ろ: 'お',
		を: 'お',
		ご: 'お',
		ぞ: 'お',
		ど: 'お',
		ぼ: 'お',
		ぽ: 'お',
	};

	return vowels[kana] || '';
}
