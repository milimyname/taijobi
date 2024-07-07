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

	// Convert the base verb
	async function convertCompoundVerbToFurigana(verb: string) {
		const parts = verb.split(/(?<=.)(?=.)/).filter((part) => part.length > 0);
		const furiganaParts = await Promise.all(parts.map(convertToFurigana));
		return furiganaParts.join('');
	}

	const baseVerbFurigana = await convertCompoundVerbToFurigana(plain);

	function getFirstEnding(furigana: string) {
		return furigana.split('</ruby>')[0] + '</ruby>';
	}

	async function getLastEnding(verb: string) {
		const converted = await convertToFurigana(verb);
		const parts = converted.split('</ruby>');
		return parts[parts.length - 1];
	}

	function combineVerbWithEnding(baseVerb: string, ending: string) {
		const parts = baseVerb.split('</ruby>');
		return parts.slice(0, -1).join('</ruby>') + ending;
	}

	return [
		{
			name: 'Present',
			positive: plain,
			positive_furigana: baseVerbFurigana,
			negative: nai,
			negative_furigana: !isHiragana(getFirstEnding(baseVerbFurigana))
				? combineVerbWithEnding(baseVerbFurigana, await getLastEnding(nai))
				: nai,
		},
		{
			name: 'Present Polite',
			positive: masu,
			positive_furigana: !isHiragana(getFirstEnding(baseVerbFurigana))
				? combineVerbWithEnding(baseVerbFurigana, await getLastEnding(masu))
				: masu,
			negative: masen,
			negative_furigana: !isHiragana(getFirstEnding(baseVerbFurigana))
				? combineVerbWithEnding(baseVerbFurigana, await getLastEnding(masen))
				: masen,
		},
		{
			name: 'Past',
			positive: ta,
			positive_furigana: !isHiragana(getFirstEnding(baseVerbFurigana))
				? combineVerbWithEnding(baseVerbFurigana, await getLastEnding(ta))
				: ta,
			negative: nakatta,
			negative_furigana: !isHiragana(getFirstEnding(baseVerbFurigana))
				? combineVerbWithEnding(baseVerbFurigana, await getLastEnding(nakatta))
				: nakatta,
		},
		{
			name: 'Past Polite',
			positive: mashita,
			positive_furigana: !isHiragana(getFirstEnding(baseVerbFurigana))
				? combineVerbWithEnding(baseVerbFurigana, await getLastEnding(mashita))
				: mashita,
			negative: masendeshita,
			negative_furigana: !isHiragana(getFirstEnding(baseVerbFurigana))
				? combineVerbWithEnding(baseVerbFurigana, await getLastEnding(masendeshita))
				: masendeshita,
		},
		{
			name: 'Te',
			positive: te,
			positive_furigana: !isHiragana(getFirstEnding(baseVerbFurigana))
				? combineVerbWithEnding(baseVerbFurigana, await getLastEnding(te))
				: te,
			negative: nakute,
			negative_furigana: !isHiragana(getFirstEnding(baseVerbFurigana))
				? combineVerbWithEnding(baseVerbFurigana, await getLastEnding(nakute))
				: nakute,
		},
		{
			name: 'Potential',
			positive: rero,
			positive_furigana: !isHiragana(getFirstEnding(baseVerbFurigana))
				? combineVerbWithEnding(baseVerbFurigana, await getLastEnding(rero))
				: rero,
			negative: renai,
			negative_furigana: !isHiragana(getFirstEnding(baseVerbFurigana))
				? combineVerbWithEnding(baseVerbFurigana, await getLastEnding(renai))
				: renai,
		},
		{
			name: 'Passive',
			positive: passive,
			positive_furigana: !isHiragana(getFirstEnding(baseVerbFurigana))
				? combineVerbWithEnding(baseVerbFurigana, await getLastEnding(passive))
				: passive,
			negative: passiveNegative,
			negative_furigana: !isHiragana(getFirstEnding(baseVerbFurigana))
				? combineVerbWithEnding(baseVerbFurigana, await getLastEnding(passiveNegative))
				: passiveNegative,
		},
		{
			name: 'Causative',
			positive: causative,
			positive_furigana: !isHiragana(getFirstEnding(baseVerbFurigana))
				? combineVerbWithEnding(baseVerbFurigana, await getLastEnding(causative))
				: causative,
			negative: causativeNegative,
			negative_furigana: !isHiragana(getFirstEnding(baseVerbFurigana))
				? combineVerbWithEnding(baseVerbFurigana, await getLastEnding(causativeNegative))
				: causativeNegative,
		},
		{
			name: 'Shortened Causative',
			positive: sasu,
			positive_furigana: !isHiragana(getFirstEnding(baseVerbFurigana))
				? combineVerbWithEnding(baseVerbFurigana, await getLastEnding(sasu))
				: sasu,
			negative: sanai,
			negative_furigana: !isHiragana(getFirstEnding(baseVerbFurigana))
				? combineVerbWithEnding(baseVerbFurigana, await getLastEnding(sanai))
				: sanai,
		},
		{
			name: 'Causative Passive',
			positive: serareru,
			positive_furigana: !isHiragana(getFirstEnding(baseVerbFurigana))
				? combineVerbWithEnding(baseVerbFurigana, await getLastEnding(serareru))
				: serareru,
			negative: serarenai,
			negative_furigana: !isHiragana(getFirstEnding(baseVerbFurigana))
				? combineVerbWithEnding(baseVerbFurigana, await getLastEnding(serarenai))
				: serarenai,
		},
		{
			name: 'Shortened Causative Passive',
			positive: sareru,
			positive_furigana: !isHiragana(getFirstEnding(baseVerbFurigana))
				? combineVerbWithEnding(baseVerbFurigana, await getLastEnding(sareru))
				: sareru,
			negative: sarenai,
			negative_furigana: !isHiragana(getFirstEnding(baseVerbFurigana))
				? combineVerbWithEnding(baseVerbFurigana, await getLastEnding(sarenai))
				: sarenai,
		},
		{
			name: 'Imperative',
			positive: ro,
			positive_furigana: !isHiragana(getFirstEnding(baseVerbFurigana))
				? combineVerbWithEnding(baseVerbFurigana, await getLastEnding(ro))
				: ro,
			negative: rona,
			negative_furigana: !isHiragana(getFirstEnding(baseVerbFurigana))
				? combineVerbWithEnding(baseVerbFurigana, await getLastEnding(rona))
				: rona,
		},
		{
			name: 'Conditional',
			positive: reba,
			positive_furigana: !isHiragana(getFirstEnding(baseVerbFurigana))
				? combineVerbWithEnding(baseVerbFurigana, await getLastEnding(reba))
				: reba,
			negative: nakereba,
			negative_furigana: !isHiragana(getFirstEnding(baseVerbFurigana))
				? combineVerbWithEnding(baseVerbFurigana, await getLastEnding(nakereba))
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
