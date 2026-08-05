// Shared display helpers for Wiktionary dict results — used by the /lexicon
// dictionary hits and its expand-on-click panel so both show the same labels.

const POS_LABEL: Record<string, string> = {
	n: 'Substantiv',
	v: 'Verb',
	adj: 'Adjektiv',
	adv: 'Adverb',
	prep: 'Präposition',
	conj: 'Konjunktion',
	pron: 'Pronomen',
	det: 'Determinator',
	intj: 'Interjektion',
	num: 'Numerale',
	part: 'Partikel',
	pfx: 'Präfix',
	sfx: 'Suffix',
	phr: 'Phrase',
	prov: 'Sprichwort',
	name: 'Eigenname',
	abbr: 'Abkürzung'
};

export function posLabel(p: string): string {
	return POS_LABEL[p] ?? p;
}
