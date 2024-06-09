import { kuroshiro } from '$lib/server/kuroshiro';
import codec from 'kamiya-codec';

async function convertToFurigana(word: string) {
	return await kuroshiro.convert(word, { to: 'hiragana', mode: 'furigana' });
}

export function getConjuctiveForm(verb: string) {
	const group3 = {
		します: 'する',
		きます: 'くる'
	};

	if (group3[verb]) {
		return group3[verb];
	}

	const stem = verb.slice(0, -2); // Remove ます
	const lastChar = verb[verb.length - 3]; // Last char of the stem

	const group1 = {
		き: 'く',
		ぎ: 'ぐ',
		し: 'す',
		ち: 'つ',
		に: 'ぬ',
		ひ: 'ふ',
		み: 'む',
		り: 'る',
		い: 'う',
		び: 'ぶ'
	};

	const group2 = {
		べ: 'べる',
		け: 'ける',
		め: 'める',
		れ: 'れる',
		え: 'える',
		ぎ: 'ぎる',
		し: 'しる',
		ち: 'ちる',
		に: 'にる',
		み: 'みる'
	};

	// Check if only 3 letter word, return the stem + る
	if (stem.length === 1) return stem + 'る';

	if (group1[lastChar]) return stem.slice(0, -1) + group1[lastChar];
	else if (group2[lastChar]) return stem + 'る';

	return verb; // Return the same if no match found
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
		'るる'
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
			'み'
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
				る: 'ら'
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
				る: 'ら'
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
	const [masen, masendeshita] = codec.conjugateAuxiliaries(plain, ['Masu'], 'Negative');

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
		true
	);
	const [, sarenai] = codec.conjugateAuxiliaries(
		plain,
		['ShortenedCausativePassive'],
		'Negative',
		true
	);

	const [ro] = codec.conjugate(plain, 'Imperative', true);
	const rona = plain + 'な';

	const [, reba] = codec.conjugate(plain, 'Conditional', true);
	const [nakereba] = codec.conjugateAuxiliaries(plain, ['Nai'], 'Conditional', true);

	return [
		{
			name: 'Present',
			positive: plain,
			positive_furigana: await convertToFurigana(plain),
			negative: nai,
			negative_furigana: await convertToFurigana(nai)
		},
		{
			name: 'Present Polite',
			positive: masu,
			positive_furigana: await kuroshiro.convert(masu, { to: 'hiragana', mode: 'furigana' }),
			negative: masen,
			negative_furigana: await kuroshiro.convert(masen, {
				to: 'hiragana',
				mode: 'furigana'
			})
		},
		{
			name: 'Past',
			positive: ta,
			positive_furigana: await convertToFurigana(ta),
			negative: nakatta,
			negative_furigana: await convertToFurigana(nakatta)
		},
		{
			name: 'Past Polite',
			positive: mashita,
			positive_furigana: await convertToFurigana(mashita),
			negative: masendeshita,
			negative_furigana: await convertToFurigana(masendeshita)
		},
		{
			name: 'Te',
			positive: te,
			positive_furigana: await convertToFurigana(te),
			negative: nakute,
			negative_furigana: await convertToFurigana(nakute)
		},
		{
			name: 'Potential',
			positive: rero,
			positive_furigana: await convertToFurigana(rero),
			negative: renai,
			negative_furigana: await convertToFurigana(renai)
		},
		{
			name: 'Passive',
			positive: passive,
			positive_furigana: await convertToFurigana(passive),
			negative: passiveNegative,
			negative_furigana: await convertToFurigana(passiveNegative)
		},
		{
			name: 'Causative',
			positive: causative,
			positive_furigana: await convertToFurigana(causative),
			negative: causativeNegative,
			negative_furigana: await convertToFurigana(causativeNegative)
		},
		{
			name: 'Shortened Causative',
			positive: sasu,
			positive_furigana: await convertToFurigana(sasu),
			negative: sanai,
			negative_furigana: await convertToFurigana(sanai)
		},
		{
			name: 'Causative Passive',
			positive: serareru,
			positive_furigana: await convertToFurigana(serareru),
			negative: serarenai,
			negative_furigana: await convertToFurigana(serarenai)
		},
		{
			name: 'Shortened Causative Passive',
			positive: sareru,
			positive_furigana: await convertToFurigana(sareru),
			negative: sarenai,
			negative_furigana: await convertToFurigana(sarenai)
		},
		{
			name: 'Imperative',
			positive: ro,
			positive_furigana: await convertToFurigana(ro),
			negative: rona,
			negative_furigana: await convertToFurigana(rona)
		},
		{
			name: 'Conditional',
			positive: reba,
			positive_furigana: await convertToFurigana(reba),
			negative: nakereba,
			negative_furigana: await convertToFurigana(nakereba)
		}
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
				: await convertToFurigana(negative.join('<br>'))
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
				: await convertToFurigana(negativePast.join('<br>'))
		},
		{
			name: 'Adverb',
			positive: adverbial[0],
			negative: '-'
		},
		{
			name: 'Noun',
			positive: noun[0],
			negative: '-'
		},
		{
			name: 'Te',
			positive: isIAdj ? te[1] : te[0],
			negative: ''
		}
	];
}
