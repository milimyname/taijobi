import { kuroshiro } from '$lib/server/kuroshiro';
import codec from 'kamiya-codec';
import { isHiragana } from 'wanakana';

async function convertToFurigana(word: string) {
	return await kuroshiro.convert(word, { to: 'hiragana', mode: 'furigana' });
}

type Key_Value = {
	[key: string]: string;
};

export function getConjuctiveForm(verb: string) {
	const group3: Key_Value = {
		します: 'する',
		きます: 'くる',
	};

	if (group3[verb]) {
		return group3[verb];
	}

	// Removing 'ます' to get the stem
	const stem = verb.slice(0, -2);
	// Getting the last character before 'ます'
	const lastChar = verb[verb.length - 3];

	const group1: Key_Value = {
		き: 'く',
		ぎ: 'ぐ',
		し: 'す',
		ち: 'つ',
		に: 'ぬ',
		ひ: 'ふ',
		み: 'む',
		り: 'る',
		い: 'う',
		び: 'ぶ',
	};

	// Check if it is an ichidan verb (e.g., めます -> める)
	const ichidanVerbs: Key_Value = {
		べ: 'べる',
		け: 'ける',
		め: 'める',
		れ: 'れる',
		え: 'える',
	};

	if (ichidanVerbs[lastChar]) {
		return stem + ichidanVerbs[lastChar].slice(1);
	}

	// For group 1 verbs
	if (group1[lastChar]) {
		return stem.slice(0, -1) + group1[lastChar];
	}

	return verb; // Fallback: return the input verb if no pattern matches
}

export function classifyWord(word: string) {
	// More nuanced logic to determine if the word is a verb or an adjective

	// Check for verbs
	// Verbs in plain form can end with any character in the 'う' row of the kana table
	const verbEndings = ['う', 'く', 'す', 'つ', 'ぬ', 'ふ', 'む', 'る', 'ぐ', 'ぶ'];
	const masuEnding = 'ます';
	const teEnding = 'て';
	const taEnding = 'た';
	const extendedVerbEndings = [
		'いる',
		'える',
		'れる',
		'せる',
		'てる',
		'ける',
		'ねる',
		'べる',
		'める',
		'るる',
	];

	// Check for adjectives
	// i-adjectives end in 'い', but not all words ending in 'い' are adjectives
	const iAdjectiveEnding = 'い';
	const naAdjectiveHint = 'な'; // This is just a hint, not definitive

	const lastCharacter = word.slice(-1);
	const secondLastCharacter = word.slice(-2, -1);

	if (
		verbEndings.includes(lastCharacter) ||
		word.endsWith(masuEnding) ||
		word.endsWith(teEnding) ||
		word.endsWith(taEnding) ||
		extendedVerbEndings.some((ending) => word.endsWith(ending))
	) {
		return 'verb';
	} else if (lastCharacter === iAdjectiveEnding && secondLastCharacter !== naAdjectiveHint) {
		// Check if it's likely an i-adjective
		// This is a simplistic check; in reality, some nouns end in 'い'
		return 'adjective';
	} else if (
		word.endsWith(naAdjectiveHint) ||
		(secondLastCharacter === naAdjectiveHint && lastCharacter === iAdjectiveEnding)
	) {
		// Words that end in 'な' or 'ない' could be na-adjectives
		// However, this can also include nouns followed by the particle 'な'
		return 'adjective';
	}

	return 'unknown'; // Fallback case
}

function determineVerbType(verb: string) {
	if (verb.endsWith('る')) {
		const stem = verb.slice(0, -1);
		const group2Endings = [
			'え',
			'け',
			'せ',
			'て',
			'ね',
			'へ',
			'め',
			'れ',
			'げ',
			'じ',
			'ぢ',
			'び',
			'ぴ',
			'み',
		];
		if (group2Endings.includes(stem.slice(-1))) {
			return 'ichidan';
		}
		return 'godan';
	}
	if (verb === 'する' || verb === 'くる') {
		return 'irregular';
	}
	return 'godan';
}

function getPassiveForm(verb: string) {
	const verbType = determineVerbType(verb);

	if (verbType === 'godan') {
		const stem = verb.slice(0, -1);
		const lastChar = verb.slice(-1);
		const passiveStem =
			stem +
			{
				う: 'わ',
				く: 'か',
				ぐ: 'が',
				す: 'さ',
				つ: 'た',
				ぬ: 'な',
				ぶ: 'ば',
				む: 'ま',
				る: 'ら',
			}[lastChar];
		return passiveStem + 'れる';
	} else if (verbType === 'ichidan') {
		return verb.slice(0, -1) + 'られる';
	} else if (verbType === 'irregular' && verb === 'する') {
		return 'される';
	} else if (verbType === 'irregular' && verb === 'くる') {
		return 'こられる';
	}

	return verb;
}

function getCausativeForm(verb: string, shortened = false) {
	const verbType = determineVerbType(verb);

	if (verbType === 'godan') {
		const stem = verb.slice(0, -1);
		const lastChar = verb.slice(-1);
		const causativeStem =
			stem +
			{
				う: 'わ',
				く: 'か',
				ぐ: 'が',
				す: 'さ',
				つ: 'た',
				ぬ: 'な',
				ぶ: 'ば',
				む: 'ま',
				る: 'ら',
			}[lastChar];
		return shortened ? causativeStem + 'す' : causativeStem + 'せる';
	} else if (verbType === 'ichidan') {
		return verb.slice(0, -1) + (shortened ? 'さす' : 'させる');
	} else if (verbType === 'irregular' && verb === 'する') {
		return shortened ? 'さす' : 'させる';
	} else if (verbType === 'irregular' && verb === 'くる') {
		return shortened ? 'こさす' : 'こさせる';
	}

	return verb;
}

export async function conjugateVerb(plain: string) {
	const [, nai] = codec.conjugate(plain, 'Negative', true);

	const [, masu] = codec.conjugate(plain, 'Conjunctive', true);
	const [masen, masendeshita] = codec.conjugateAuxiliaries(plain, ['Masu'], 'Negative', true);

	const [mashita] = codec.conjugateAuxiliaries(plain, ['Masu'], 'Ta', true);

	const [ta] = codec.conjugate(plain, 'Ta', true);
	const [nakatta] = codec.conjugateAuxiliaries(plain, ['Nai'], 'Ta');

	const [te] = codec.conjugate(plain, 'Te', true);
	const [nakute] = codec.conjugateAuxiliaries(plain, ['Nai'], 'Te');

	const [rero] = codec.conjugateAuxiliaries(plain, ['Potential'], 'Dictionary');
	const [, renai] = codec.conjugateAuxiliaries(plain, ['Potential'], 'Negative');

	const passive = getPassiveForm(plain);
	const [, passiveNegative] = codec.conjugate(passive, 'Negative', true);

	const causative = getCausativeForm(plain);
	const [, causativeNegative] = codec.conjugate(causative, 'Negative', true);

	const [sasu] = codec.conjugateAuxiliaries(plain, ['ShortenedCausative'], 'Dictionary', true);
	const [, sanai] = codec.conjugateAuxiliaries(plain, ['ShortenedCausative'], 'Negative', true);

	const [serareru] = codec.conjugateAuxiliaries(plain, ['CausativePassive'], 'Dictionary', true);
	const [, serarenai] = codec.conjugateAuxiliaries(plain, ['CausativePassive'], 'Negative', true);

	const [sareru] = codec.conjugateAuxiliaries(
		plain,
		['ShortenedCausativePassive'],
		'Dictionary',
		true,
	);
	const [, sarenai] = codec.conjugateAuxiliaries(
		plain,
		['ShortenedCausativePassive'],
		'Negative',
		true,
	);

	const [ro] = codec.conjugate(plain, 'Imperative', true);
	const rona = plain + 'な';

	const [, reba] = codec.conjugate(plain, 'Conditional', true);
	const [nakereba] = codec.conjugateAuxiliaries(plain, ['Nai'], 'Conditional', true);

	// Convert the base verb only once
	const baseVerbFurigana = await convertToFurigana(plain);

	const firstEnding = baseVerbFurigana.split('</ruby>')[0];

	async function getLastEnding(verb: string) {
		return (await convertToFurigana(verb)).split('</ruby>')[1];
	}

	return [
		{
			name: 'Present',
			positive: plain,
			positive_furigana: baseVerbFurigana,
			negative: nai,
			negative_furigana: !isHiragana(firstEnding) ? firstEnding + (await getLastEnding(nai)) : nai,
		},
		{
			name: 'Present Polite',
			positive: masu,
			positive_furigana: !isHiragana(firstEnding)
				? firstEnding + (await getLastEnding(masu))
				: masu,
			negative: masen,
			negative_furigana: !isHiragana(firstEnding)
				? firstEnding + (await getLastEnding(masen))
				: masen,
		},
		{
			name: 'Past',
			positive: ta,
			positive_furigana: !isHiragana(firstEnding) ? firstEnding + (await getLastEnding(ta)) : ta,
			negative: nakatta,
			negative_furigana: !isHiragana(firstEnding)
				? firstEnding + (await getLastEnding(nakatta))
				: nakatta,
		},
		{
			name: 'Past Polite',
			positive: mashita,
			positive_furigana: !isHiragana(firstEnding)
				? firstEnding + (await getLastEnding(mashita))
				: mashita,
			negative: masendeshita,
			negative_furigana: !isHiragana(firstEnding)
				? firstEnding + (await getLastEnding(masendeshita))
				: masendeshita,
		},
		{
			name: 'Te',
			positive: te,
			positive_furigana: !isHiragana(firstEnding) ? firstEnding + (await getLastEnding(te)) : te,
			negative: nakute,
			negative_furigana: !isHiragana(firstEnding)
				? firstEnding + (await getLastEnding(nakute))
				: nakute,
		},
		{
			name: 'Potential',
			positive: rero,
			positive_furigana: !isHiragana(firstEnding)
				? firstEnding + (await getLastEnding(rero))
				: rero,
			negative: renai,
			negative_furigana: !isHiragana(firstEnding)
				? firstEnding + (await getLastEnding(renai))
				: renai,
		},
		{
			name: 'Passive',
			positive: passive,
			positive_furigana: !isHiragana(firstEnding)
				? firstEnding + (await getLastEnding(passive))
				: passive,
			negative: passiveNegative,
			negative_furigana: !isHiragana(firstEnding)
				? firstEnding + (await getLastEnding(passiveNegative))
				: passiveNegative,
		},
		{
			name: 'Causative',
			positive: causative,
			positive_furigana: !isHiragana(firstEnding)
				? firstEnding + (await getLastEnding(causative))
				: causative,
			negative: causativeNegative,
			negative_furigana: !isHiragana(firstEnding)
				? firstEnding + (await getLastEnding(causativeNegative))
				: causativeNegative,
		},
		{
			name: 'Shortened Causative',
			positive: sasu,
			positive_furigana: !isHiragana(firstEnding)
				? firstEnding + (await getLastEnding(sasu))
				: sasu,
			negative: sanai,
			negative_furigana: !isHiragana(firstEnding)
				? firstEnding + (await getLastEnding(sanai))
				: sanai,
		},
		{
			name: 'Causative Passive',
			positive: serareru,
			positive_furigana: !isHiragana(firstEnding)
				? firstEnding + (await getLastEnding(serareru))
				: serareru,
			negative: serarenai,
			negative_furigana: !isHiragana(firstEnding)
				? firstEnding + (await getLastEnding(serarenai))
				: serarenai,
		},
		{
			name: 'Shortened Causative Passive',
			positive: sareru,
			positive_furigana: !isHiragana(firstEnding)
				? firstEnding + (await getLastEnding(sareru))
				: sareru,
			negative: sarenai,
			negative_furigana: !isHiragana(firstEnding)
				? firstEnding + (await getLastEnding(sarenai))
				: sarenai,
		},
		{
			name: 'Imperative',
			positive: ro,
			positive_furigana: !isHiragana(firstEnding) ? firstEnding + (await getLastEnding(ro)) : ro,
			negative: rona,
			negative_furigana: !isHiragana(firstEnding)
				? firstEnding + (await getLastEnding(rona))
				: rona,
		},
		{
			name: 'Conditional',
			positive: reba,
			positive_furigana: !isHiragana(firstEnding)
				? firstEnding + (await getLastEnding(reba))
				: reba,
			negative: nakereba,
			negative_furigana: !isHiragana(firstEnding)
				? firstEnding + (await getLastEnding(nakereba))
				: nakereba,
		},
	];
}

// TODO: Tooltips
// 静かなではない (shizuka na de wa nai): Informal, slightly unnatural; commonly split into ではない or じゃない.
// 静かなでない (shizuka na de nai): Informal and somewhat colloquial.
// 静かなじゃない (shizuka na ja nai): Commonly used in casual speech.
// 静かなではありません (shizuka na de wa arimasen): Formal, used in polite conversation and writing.
export async function conjugateAdjective(adjective: string) {
	const isIAdj = adjective.trim().endsWith('い');

	const present = codec.adjConjugate(adjective, 'Present', isIAdj);
	const negative = codec.adjConjugate(adjective, 'Negative', isIAdj);

	const past = codec.adjConjugate(adjective, 'Past', isIAdj);
	const negativePast = codec.adjConjugate(adjective, 'NegativePast', isIAdj);

	const adverbial = codec.adjConjugate(adjective, 'Adverbial', isIAdj);

	const noun = codec.adjConjugate(adjective, 'Noun', isIAdj);

	const te = codec.adjConjugate(adjective, 'ConjunctiveTe', isIAdj);

	return [
		{
			name: 'Present',
			positive: present.join('<br>'),
			positive_furigana: await convertToFurigana(present.join('<br>')),
			negative: isIAdj ? negative[0] : negative.join('<br>'),
			negative_furigana: isIAdj
				? await convertToFurigana(negative[0])
				: await convertToFurigana(negative.join('<br>')),
		},
		{
			name: 'Past',
			positive: isIAdj ? past[0] : past.join('<br>'),
			positive_furigana: isIAdj
				? await convertToFurigana(past[0])
				: await convertToFurigana(past.join('<br>')),
			negative: isIAdj ? negativePast[0] : negativePast.join('<br>'),
			negative_furigana: isIAdj
				? await convertToFurigana(negativePast[0])
				: await convertToFurigana(negativePast.join('<br>')),
		},
		{
			name: 'Adverb',
			positive: adverbial[0],
			negative: '-',
		},
		{
			name: 'Noun',
			positive: noun[0],
			negative: '-',
		},
		{
			name: 'Te',
			positive: isIAdj ? te[1] : te[0],
			negative: '',
		},
	];
}
