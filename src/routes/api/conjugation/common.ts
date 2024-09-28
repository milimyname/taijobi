import { convertToFurigana, convertToKana } from '$lib/server/kuroshiro';
import { getPlainForm } from '$lib/utils/getPlainForm';
import codec from 'kamiya-codec';

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

export async function conjugateVerb(word: string) {
	const plain = getPlainForm(word);

	// Check if the verb is a compound verb ending with する
	const isCompoundSuru = plain.endsWith('する');
	let nounPart = '';
	let verbPart = plain;

	if (isCompoundSuru) {
		nounPart = plain.slice(0, -2);
		verbPart = 'する';
	}

	// Helper function to combine noun part with conjugated verb
	const combineWithNoun = (conjugated: string) =>
		isCompoundSuru ? nounPart + conjugated : conjugated;

	// Conjugate only the verb part
	const [, nai] = codec.conjugate(verbPart, 'Negative', true);
	const [, masu] = codec.conjugate(verbPart, 'Conjunctive', true);
	const [masen, masendeshita] = codec.conjugateAuxiliaries(verbPart, ['Masu'], 'Negative', true);
	const [mashita] = codec.conjugateAuxiliaries(verbPart, ['Masu'], 'Ta', true);
	const [ta] = codec.conjugate(verbPart, 'Ta', true);
	const [nakatta] = codec.conjugateAuxiliaries(verbPart, ['Nai'], 'Ta', true);
	const [te] = codec.conjugate(verbPart, 'Te', true);
	const [nakute] = codec.conjugateAuxiliaries(verbPart, ['Nai'], 'Te', true);
	const [rero] = codec.conjugateAuxiliaries(verbPart, ['Potential'], 'Dictionary');
	const [, renai] = codec.conjugateAuxiliaries(verbPart, ['Potential'], 'Negative');
	const passive = getPassiveForm(verbPart);
	const [, passiveNegative] = codec.conjugate(passive, 'Negative', true);
	const causative = getCausativeForm(verbPart);
	const [, causativeNegative] = codec.conjugate(causative, 'Negative', true);
	const [sasu] = codec.conjugateAuxiliaries(verbPart, ['ShortenedCausative'], 'Dictionary', true);
	const [, sanai] = codec.conjugateAuxiliaries(verbPart, ['ShortenedCausative'], 'Negative', true);
	const [serareru] = codec.conjugateAuxiliaries(verbPart, ['CausativePassive'], 'Dictionary', true);
	const [, serarenai] = codec.conjugateAuxiliaries(
		verbPart,
		['CausativePassive'],
		'Negative',
		true,
	);
	const [sareru] = codec.conjugateAuxiliaries(
		verbPart,
		['ShortenedCausativePassive'],
		'Dictionary',
		true,
	);
	const [, sarenai] = codec.conjugateAuxiliaries(
		verbPart,
		['ShortenedCausativePassive'],
		'Negative',
		true,
	);
	const [ro] = codec.conjugate(verbPart, 'Imperative', true);
	const rona = verbPart + 'な';
	const [, reba] = codec.conjugate(verbPart, 'Conditional', true);
	const [nakereba] = codec.conjugateAuxiliaries(verbPart, ['Nai'], 'Conditional', true);

	// Combine the noun part with the conjugated verb part
	return [
		{
			name: 'Present',
			positive: {
				plain,
				furigana: await convertToFurigana(plain),
				kana: await convertToKana(plain),
			},
			negative: {
				plain: combineWithNoun(nai),
				furigana: await convertToFurigana(combineWithNoun(nai)),
				kana: await convertToKana(nai),
			},
		},
		{
			name: 'Present Polite',
			positive: {
				plain: combineWithNoun(masu),
				furigana: await convertToFurigana(combineWithNoun(masu)),
				kana: await convertToKana(masu),
			},
			negative: {
				plain: combineWithNoun(masen),
				furigana: await convertToFurigana(combineWithNoun(masen)),
				kana: await convertToKana(masen),
			},
		},
		{
			name: 'Past',
			positive: {
				plain: combineWithNoun(ta),
				furigana: await convertToFurigana(combineWithNoun(ta)),
				kana: await convertToKana(ta),
			},
			negative: {
				plain: combineWithNoun(nakatta),
				furigana: await convertToFurigana(combineWithNoun(nakatta)),
				kana: await convertToKana(nakatta),
			},
		},
		{
			name: 'Past Polite',
			positive: {
				plain: combineWithNoun(mashita),
				furigana: await convertToFurigana(combineWithNoun(mashita)),
				kana: await convertToKana(mashita),
			},
			negative: {
				plain: combineWithNoun(masendeshita),
				furigana: await convertToFurigana(combineWithNoun(masendeshita)),
				kana: await convertToKana(masendeshita),
			},
		},
		{
			name: 'Te',
			positive: {
				plain: combineWithNoun(te),
				furigana: await convertToFurigana(combineWithNoun(te)),
				kana: await convertToKana(te),
			},
			negative: {
				plain: combineWithNoun(nakute),
				furigana: await convertToFurigana(combineWithNoun(nakute)),
				kana: await convertToKana(nakute),
			},
		},
		{
			name: 'Potential',
			positive: {
				plain: combineWithNoun(rero),
				furigana: await convertToFurigana(combineWithNoun(rero)),
				kana: await convertToKana(rero),
			},
			negative: {
				plain: combineWithNoun(renai),
				furigana: await convertToFurigana(combineWithNoun(renai)),
				kana: await convertToKana(renai),
			},
		},
		{
			name: 'Passive',
			positive: {
				plain: combineWithNoun(passive),
				furigana: await convertToFurigana(combineWithNoun(passive)),
				kana: await convertToKana(passive),
			},
			negative: {
				plain: combineWithNoun(passiveNegative),
				furigana: await convertToFurigana(combineWithNoun(passiveNegative)),
				kana: await convertToKana(passiveNegative),
			},
		},
		{
			name: 'Causative',
			positive: {
				plain: combineWithNoun(causative),
				furigana: await convertToFurigana(combineWithNoun(causative)),
				kana: await convertToKana(causative),
			},
			negative: {
				plain: combineWithNoun(causativeNegative),
				furigana: await convertToFurigana(combineWithNoun(causativeNegative)),
				kana: await convertToKana(causativeNegative),
			},
		},
		{
			name: 'Shortened Causative',
			positive: {
				plain: combineWithNoun(sasu),
				furigana: await convertToFurigana(combineWithNoun(sasu)),
				kana: await convertToKana(sasu),
			},
			negative: {
				plain: combineWithNoun(sanai),
				furigana: await convertToFurigana(combineWithNoun(sanai)),
				kana: await convertToKana(sanai),
			},
		},
		{
			name: 'Causative Passive',
			positive: {
				plain: combineWithNoun(serareru),
				furigana: await convertToFurigana(combineWithNoun(serareru)),
				kana: await convertToKana(serareru),
			},
			negative: {
				plain: combineWithNoun(serarenai),
				furigana: await convertToFurigana(combineWithNoun(serarenai)),
				kana: await convertToKana(serarenai),
			},
		},
		{
			name: 'Shortened Causative Passive',
			positive: {
				plain: combineWithNoun(sareru),
				furigana: await convertToFurigana(combineWithNoun(sareru)),
				kana: await convertToKana(sareru),
			},
			negative: {
				plain: combineWithNoun(sarenai),
				furigana: await convertToFurigana(combineWithNoun(sarenai)),
				kana: await convertToKana(sarenai),
			},
		},
		{
			name: 'Imperative',
			positive: {
				plain: combineWithNoun(ro),
				furigana: await convertToFurigana(combineWithNoun(ro)),
				kana: await convertToKana(ro),
			},
			negative: {
				plain: combineWithNoun(rona),
				furigana: await convertToFurigana(combineWithNoun(rona)),
				kana: await convertToKana(rona),
			},
		},
		{
			name: 'Conditional',
			positive: {
				plain: combineWithNoun(reba),
				furigana: await convertToFurigana(combineWithNoun(reba)),
				kana: await convertToKana(reba),
			},
			negative: {
				plain: combineWithNoun(nakereba),
				furigana: await convertToFurigana(combineWithNoun(nakereba)),
				kana: await convertToKana(nakereba),
			},
		},
	];
}

// TODO: Tooltips
// 静かなではない (shizuka na de wa nai): Informal, slightly unnatural; commonly split into ではない or じゃない.
// 静かなでない (shizuka na de nai): Informal and somewhat colloquial.
// 静かなじゃない (shizuka na ja nai): Commonly used in casual speech.
// 静かなではありません (shizuka na de wa arimasen): Formal, used in polite conversation and writing.
export async function conjugateAdjective(adjective: string) {
	// More robust check for い-adjectives
	const isIAdj =
		adjective.trim().endsWith('い') && !['きれい', 'ゆうめい', 'きらい'].includes(adjective.trim());

	const present = codec.adjConjugate(adjective, 'Present', isIAdj);
	const negative = codec.adjConjugate(adjective, 'Negative', isIAdj);
	const past = codec.adjConjugate(adjective, 'Past', isIAdj);
	const negativePast = codec.adjConjugate(adjective, 'NegativePast', isIAdj);
	const adverbial = codec.adjConjugate(adjective, 'Adverbial', isIAdj);
	const noun = codec.adjConjugate(adjective, 'Noun', isIAdj);
	const te = codec.adjConjugate(adjective, 'ConjunctiveTe', isIAdj);

	// Helper function to join multiple forms and generate furigana
	type ReturnPromise = { plain: string; furigana: string; kana: string };

	async function processForm(form: string[], separator = '<br>'): Promise<ReturnPromise> {
		const plainText = form.join(separator);
		return {
			plain: plainText,
			furigana: await convertToFurigana(plainText),
			kana: await convertToKana(plainText),
		};
	}

	// Helper function to add polite form
	function addPoliteForm(form: string): string {
		return isIAdj ? form + 'です' : form + 'です';
	}

	return [
		{
			name: 'Present',
			positive: await processForm(present),
			negative: await processForm(negative),
			positive_polite: await processForm([addPoliteForm(present[0])]),
			negative_polite: await processForm([addPoliteForm(negative[0])]),
		},
		{
			name: 'Past',
			positive: await processForm(past),
			negative: await processForm(negativePast),
			positive_polite: await processForm([addPoliteForm(past[0])]),
			negative_polite: await processForm([addPoliteForm(negativePast[0])]),
		},
		{
			name: 'Adverb',
			positive: await processForm(adverbial),
			negative: { plain: '-', furigana: '-' },
		},
		{
			name: 'Noun',
			positive: await processForm(noun),
			negative: { plain: '-', furigana: '-' },
		},
		{
			name: 'Te',
			positive: await processForm([isIAdj ? te[1] : te[0]]),
			negative: { plain: '-', furigana: '-' },
		},
	];
}
