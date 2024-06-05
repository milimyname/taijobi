import { kuroshiro } from '$lib/server/kuroshiro';

function conjugatedIkuAndAru(verb: string) {
	// Special Irrgeular Verbs ある
	if (verb === 'ある') {
		return {
			Affirmative: {
				Present: {
					word: 'ある',
					furigana: 'ある'
				},
				Present_Polite: {
					word: 'あります',
					furigana: 'あります'
				},
				Past: {
					word: 'あった',
					furigana: 'あった'
				},
				Past_Polite: {
					word: 'ありました',
					furigana: 'ありました'
				},
				Te: {
					word: 'あって',
					furigana: 'あって'
				},
				Potential: {
					word: 'あれる',
					furigana: 'あれる'
				},
				Passive: {
					word: 'あられる',
					furigana: 'あられる'
				},
				Causative: {
					word: 'あらせる',
					furigana: 'あらせる'
				},
				Causative_Passive: {
					word: 'あらせられる',
					furigana: 'あらせられる'
				},
				Imperative: {
					word: 'あれ',
					furigana: 'あれ'
				},
				Ba: {
					word: 'あれば',
					furigana: 'あれば'
				}
			},
			Negative: {
				Present: {
					word: 'ない',
					furigana: 'ない'
				},
				Present_Polite: {
					word: 'ありません',
					furigana: 'ありません'
				},
				Past: {
					word: 'なかった',
					furigana: 'なかった'
				},
				Past_Polite: {
					word: 'ありませんでした',
					furigana: 'ありませんでした'
				},
				Te: {
					word: 'なくて',
					furigana: 'なくて'
				},
				Potential: {
					word: 'あり得ない',
					furigana: 'あり得ない'
				},
				Passive: {
					word: 'あられない',
					furigana: 'あられない'
				},
				Causative: {
					word: 'あらせない',
					furigana: 'あらせない'
				},
				Causative_Passive: {
					word: 'あらせられない',
					furigana: 'あらせられない'
				},
				Imperative: {
					word: 'あるな',
					furigana: 'あるな'
				},
				Ba: {
					word: 'なければ',
					furigana: 'なければ'
				}
			}
		};
	}

	// 行く (iku) is an irregular verb
	if (verb === 'いく') {
		return {
			Affirmative: {
				Present: {
					word: '行く',
					furigana: '行く'
				},
				Present_Polite: {
					word: '行きます',
					furigana: '行きます'
				},
				Past: {
					word: '行った',
					furigana: '行った'
				},
				Past_Polite: {
					word: '行きました',
					furigana: '行きました'
				},
				Te: {
					word: '行って',
					furigana: '行って'
				},
				Potential: {
					word: '行ける',
					furigana: '行ける'
				},
				Passive: {
					word: '行かれる',
					furigana: '行かれる'
				},
				Causative: {
					word: '行かせる',
					furigana: '行かせる'
				},
				Causative_Passive: {
					word: '行かせられる',
					furigana: '行かせられる'
				},
				Imperative: {
					word: '行け',
					furigana: '行け'
				},
				Ba: {
					word: '行けば',
					furigana: '行けば'
				}
			},
			Negative: {
				Present: {
					word: '行かない',
					furigana: '行かない'
				},
				Present_Polite: {
					word: '行きません',
					furigana: '行きません'
				},
				Past: {
					word: '行かなかった',
					furigana: '行かなかった'
				},
				Past_Polite: {
					word: '行きませんでした',
					furigana: '行きませんでした'
				},
				Te: {
					word: '行かなくて',
					furigana: '行かなくて'
				},
				Potential: {
					word: '行けない',
					furigana: '行けない'
				},
				Passive: {
					word: '行かれない',
					furigana: '行かれない'
				},
				Causative: {
					word: '行かせない',
					furigana: '行かせない'
				},
				Causative_Passive: {
					word: '行かせられない',
					furigana: '行かせられない'
				},
				Imperative: {
					word: '行くな',
					furigana: '行くな'
				},
				Ba: {
					word: '行かなければ',
					furigana: '行かなければ'
				}
			}
		};
	}
}

export async function conjugateVerb(verb: string, word?: string) {
	// Convert to dictionary form (assumes verb is given in polite non-past, e.g., 食べます -> 食べる)
	let dictionaryForm;
	if (verb.endsWith('ます')) {
		dictionaryForm = verb.slice(0, -2) + 'る';
	} else {
		dictionaryForm = verb; // assuming the verb is already in dictionary form
	}

	// Determine the verb group
	let group;
	if (dictionaryForm === 'くる') {
		group = 3; // くる is an irregular verb
	} else if (dictionaryForm === 'する') {
		group = 4; // する is an irregular verb
	} else if (
		dictionaryForm.endsWith('る') &&
		(dictionaryForm.includes('いる') || dictionaryForm.includes('える'))
	) {
		group = 2; // Group 2 verbs
	} else {
		group = 1; // Group 1 verbs
	}

	const stem = dictionaryForm.slice(0, -1); // Remove last character to get the stem

	// Special Irrgeular Verbs ある or いく
	if (verb === 'ある' || verb === 'いく') return conjugatedIkuAndAru(verb);

	const furiganaStem = word?.slice(0, -1) || ''; // Remove last character to get the stem

	const furigana = await kuroshiro.convert(furiganaStem, { to: 'hiragana', mode: 'furigana' });

	// Conjugate based on the group
	switch (group) {
		case 1: {
			// Group 1: う-verbs (Godan)
			const lastKana = dictionaryForm.slice(-1);
			const kanaMap: { [key: string]: string } = {
				う: 'って',
				つ: 'って',
				る: 'って',
				ぶ: 'んで',
				む: 'んで',
				ぬ: 'んで',
				く: 'いて',
				ぐ: 'いで',
				す: 'して'
			};
			const teEnding = kanaMap[lastKana] || 'って';

			return [
				{
					name: 'Present',
					positive: dictionaryForm,
					positive_furigana: word,
					negative: `${stem}ない`,
					negative_furigana: furigana + `${stem}ない`
				},
				{
					name: 'Present Polite',
					positive: `${stem}ます`,
					positive_furigana: furigana + `${stem}ます`,
					negative: `${stem}ません`,
					negative_furigana: furigana + `${stem}ません`
				},

				{
					name: 'Past',
					positive: `${stem}${teEnding.slice(0, -1)}た`,
					positive_furigana: furigana + `${stem}${teEnding.slice(0, -1)}た`,
					negative: `${stem}なかった`,
					negative_furigana: furigana + `${stem}なかった`
				},
				{
					name: 'Past Polite',
					positive: `${stem}ました`,
					positive_furigana: furigana + `${stem}ました`,
					negative: `${stem}ませんでした`,
					negative_furigana: furigana + `${stem}ませんでした`
				},
				{
					name: 'Te',
					positive: `${stem}${teEnding}`,
					positive_furigana: furigana + `${stem}${teEnding}`,
					negative: `${stem}なくて`,
					negative_furigana: furigana + `${stem}なくて`
				},
				{
					name: 'Potential',
					positive: `${stem.slice(0, -1)}える`,
					positive_furigana: furigana + `${stem.slice(0, -1)}える`,
					negative: `${stem.slice(0, -1)}えない`
				},
				{
					name: 'Passive',
					positive: `${stem.slice(0, -1)}られる`,
					positive_furigana: furigana + `${stem.slice(0, -1)}られる`,
					negative: `${stem.slice(0, -1)}られない`
				},
				{
					name: 'Causative',
					positive: `${stem.slice(0, -1)}せる`,
					positive_furigana: furigana + `${stem.slice(0, -1)}せる`,
					negative: `${stem.slice(0, -1)}せない`
				},
				{
					name: 'Causative Passive',
					positive: `${stem.slice(0, -1)}せられる`,
					positive_furigana: furigana + `${stem.slice(0, -1)}せられる`,
					negative: `${stem.slice(0, -1)}せられない`
				},
				{
					name: 'Imperative',
					positive: `${stem}ろ`,
					positive_furigana: furigana + `${stem}ろ`,
					negative: `${stem}るな`
				},
				{
					name: 'Ba',
					positive: `${stem}${teEnding.slice(0, -1)}ば`,
					positive_furigana: furigana + `${stem}${teEnding.slice(0, -1)}ば`,
					negative: `${stem}なければ`
				}
			];

			break;
		}
		case 2: {
			// Group 2: る-verbs (Ichidan)
			return [
				{
					name: 'Present',
					positive: dictionaryForm,
					positive_furigana: word,
					negative: `${stem}ない`,
					negative_furigana: furigana + `${stem}ない`
				},
				{
					name: 'Present Polite',
					positive: `${stem}ます`,
					positive_furigana: furigana + `${stem}ます`,
					negative: `${stem}ません`,
					negative_furigana: furigana + `${stem}ません`
				},

				{
					name: 'Past',
					positive: `${stem}た`,
					positive_furigana: furigana + `${stem}た`,
					negative: `${stem}なかった`,
					negative_furigana: furigana + `${stem}なかった`
				},
				{
					name: 'Past Polite',
					positive: `${stem}ました`,
					positive_furigana: furigana + `${stem}ました`,
					negative: `${stem}ませんでした`,
					negative_furigana: furigana + `${stem}ませんでした`
				},
				{
					name: 'Te',
					positive: `${stem}て`,
					positive_furigana: furigana + `${stem}て`,
					negative: `${stem}なくて`,
					negative_furigana: furigana + `${stem}なくて`
				},
				{
					name: 'Potential',
					positive: `${stem}られる`,
					positive_furigana: furigana + `${stem}られる`,
					negative: `${stem}られない`
				},
				{
					name: 'Passive',
					positive: `${stem}られる`,
					positive_furigana: furigana + `${stem}られる`,
					negative: `${stem}られない`
				},
				{
					name: 'Causative',
					positive: `${stem}させる`,
					positive_furigana: furigana + `${stem}させる`,
					negative: `${stem}させない`
				},
				{
					name: 'Causative Passive',
					positive: `${stem}させられる`,
					positive_furigana: furigana + `${stem}させら`,
					negative: `${stem}させられない`,
					negative_furigana: furigana + `${stem}させられない`
				},
				{
					name: 'Imperative',
					positive: `${stem}ろ`,
					positive_furigana: furigana + `${stem}ろ`,
					negative: `${stem}るな`
				},
				{
					name: 'Ba',
					positive: `${stem}れば`,
					positive_furigana: furigana + `${stem}れば`,
					negative: `${stem}なければ`
				}
			];

			break;
		}
		case 3: {
			// Irregular: 来る (kuru)

			return [
				{
					name: 'Present',
					positive: 'くる',
					positive_furigana: furigana + '来る',
					negative: 'こない',
					negative_furigana: furigana + '来ない'
				},
				{
					name: 'Present Polite',
					positive: 'きます',
					positive_furigana: furigana + '来ます',
					negative: 'きません',
					negative_furigana: furigana + '来ません'
				},

				{
					name: 'Past',
					positive: 'きた',
					positive_furigana: furigana + '来た',
					negative: 'こなかった',
					negative_furigana: furigana + '来なかった'
				},
				{
					name: 'Past Polite',
					positive: 'きました',
					positive_furigana: furigana + '来ました',
					negative: 'きませんでした',
					negative_furigana: furigana + '来ませんでした'
				},
				{
					name: 'Te',
					positive: 'きて',
					positive_furigana: furigana + '来て',
					negative: 'こなくて',
					negative_furigana: furigana + '来なくて'
				},
				{
					name: 'Potential',
					positive: 'これる',
					positive_furigana: furigana + '来られる',
					negative: 'これない',
					negative_furigana: furigana + '来られない'
				},
				{
					name: 'Passive',
					positive: 'られる',
					positive_furigana: furigana + '来られる',
					negative: 'られない',
					negative_furigana: furigana + '来られない'
				},
				{
					name: 'Causative',
					positive: 'させる',
					positive_furigana: furigana + '来させる',
					negative: 'させない',
					negative_furigana: furigana + '来させない'
				},
				{
					name: 'Causative Passive',
					positive: 'させられる',
					positive_furigana: furigana + '来させられる',
					negative: 'させられない',
					negative_furigana: furigana + '来させられない'
				},
				{
					name: 'Imperative',
					positive: '来い',
					positive_furigana: furigana + '来い',
					negative: '来るな',
					negative_furigana: furigana + '来るな'
				},
				{
					name: 'Ba',
					positive: 'くれば',
					positive_furigana: furigana + '来れば',
					negative: 'こなければ',
					negative_furigana: furigana + '来なければ'
				}
			];

			break;
		}
		case 4: {
			// Irregular: する (suru)

			return [
				{
					name: 'Present',
					positive: 'する',
					positive_furigana: 'する',
					negative: 'しない',
					negative_furigana: 'しない'
				},
				{
					name: 'Present Polite',
					positive: 'します',
					positive_furigana: 'します',
					negative: 'しません',
					negative_furigana: 'しません'
				},

				{
					name: 'Past',
					positive: 'した',
					positive_furigana: 'した',
					negative: 'しなかった',
					negative_furigana: 'しなかった'
				},
				{
					name: 'Past Polite',
					positive: 'しました',
					positive_furigana: 'しました',
					negative: 'しませんでした',
					negative_furigana: 'しませんでした'
				},
				{
					name: 'Te',
					positive: 'して',
					positive_furigana: 'して',
					negative: 'しなくて',
					negative_furigana: 'しなくて'
				},
				{
					name: 'Potential',
					positive: 'できる',
					positive_furigana: 'できる',
					negative: 'できない',
					negative_furigana: 'できない'
				},
				{
					name: 'Passive',
					positive: 'される',
					positive_furigana: 'される',
					negative: 'されない',
					negative_furigana: 'されない'
				},
				{
					name: 'Causative',
					positive: 'させる',
					positive_furigana: 'させる',
					negative: 'させない',
					negative_furigana: 'させない'
				},
				{
					name: 'Causative Passive',
					positive: 'させられる',
					positive_furigana: 'させられる',
					negative: 'させられない',
					negative_furigana: 'させられない'
				},
				{
					name: 'Imperative',
					positive: 'しろ',
					positive_furigana: 'しろ',
					negative: 'するな',
					negative_furigana: 'するな'
				},
				{
					name: 'Ba',
					positive: 'すれば',
					positive_furigana: 'すれば',
					negative: 'しなければ',
					negative_furigana: 'しなければ'
				}
			];

			break;
		}
	}
}

export function conjugateAdjective(adjective: string) {
	let root: string;
	let present: string, adverb: string, noun: string;
	let te: string, past: string, negative: string, past_negative: string;

	// Handling i-adjectives
	if (adjective.endsWith('い') && !adjective.endsWith('ない')) {
		root = adjective.slice(0, -1); // Remove the last character 'い'

		present = adjective; // The adjective itself is the present form
		adverb = `${root}く`; // Adverbial form by changing 'い' to 'く'
		noun = `${root}さ`; // Noun form by changing 'い' to 'さ'
		te = `${root}くて`; // Te-form by adding 'て' to adverbial form
		past = `${root}かった`; // Past form by adding 'かった' to root
		negative = `${root}くない`; // Negative form by adding 'ない' to adverbial form
		past_negative = `${root}くなかった`; // Past negative form by adding 'なかった' to adverbial form
	} else if (adjective.endsWith('な')) {
		// Simplified check for na-adjectives
		root = adjective.slice(0, -1); // Assume adjective form minus 'な' is the root

		present = `${adjective}だ`; // Present form is the adjective with 'だ' for declarative mood
		adverb = `${root}に`; // Adverbial form by changing 'な' to 'に'
		noun = adjective; // The adjective itself can act as a noun form
		te = `${adjective}で`; // Te-form uses the whole adjective plus 'で'
		past = `${adjective}だった`; // Past form is the adjective with 'だった'
		negative = `${adjective}ではない`; // Negative form adds 'ではない'
		past_negative = `${adjective}ではなかった`; // Past negative form adds 'ではなかった'
	} else {
		// Default handling if not clearly i-adjective or na-adjective
		// Assuming as na-adjective for safety
		present = `${adjective}だ`;
		adverb = `${adjective}に`;
		noun = adjective;
		te = `${adjective}で`;
		past = `${adjective}だった`;
		negative = `${adjective}ではない`;
		past_negative = `${adjective}ではなかった`;
	}

	return {
		present,
		adverb,
		noun,
		te,
		past,
		negative,
		past_negative
	};
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
