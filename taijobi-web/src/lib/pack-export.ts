// Assemble a `tag='personal'` SQLite pack into the community-pack JSON shape
// and validate it against the strict schema. If validation passes, the user
// can save the returned JSON to `packs/community/<id>.json` and open a PR.
//
// Runs the same `validatePack` the CI workflow runs — byte-for-byte parity.

import { validatePack } from '../../../packs/validator';
import { getLessons, getPacks, getVocabulary } from './wasm';

export type ExportResult =
	| { ok: true; filename: string; json: string; wordCount: number }
	| { ok: false; error: string };

type VocabEntry = { word: string; pinyin?: string; translation: string };
type LessonEntry = { id: string; title?: string; sort_order: number; vocabulary: VocabEntry[] };

export function exportPackAsJson(packId: string): ExportResult {
	const pack = getPacks().find((p) => p.id === packId);
	if (!pack) return { ok: false, error: `Paket "${packId}" nicht gefunden` };

	const lessons = getLessons(packId);
	if (lessons.length === 0) return { ok: false, error: 'Paket hat keine Lektionen' };

	const assembledLessons: LessonEntry[] = lessons.map((l) => {
		const vocabulary: VocabEntry[] = [];
		const limit = 200;
		let offset = 0;
		while (true) {
			const batch = getVocabulary(l.id, offset, limit);
			if (batch.length === 0) break;
			for (const v of batch) {
				const item: VocabEntry = { word: v.word, translation: v.translation ?? '' };
				if (v.pinyin) item.pinyin = v.pinyin;
				vocabulary.push(item);
			}
			if (batch.length < limit) break;
			offset += limit;
		}
		const out: LessonEntry = { id: l.id, sort_order: l.sort_order, vocabulary };
		if (l.title) out.title = l.title;
		return out;
	});

	const candidate = {
		id: pack.id,
		name: pack.name,
		version: pack.version,
		language_pair: pack.language_pair,
		lessons: assembledLessons
	};

	try {
		validatePack(candidate);
	} catch (err) {
		return { ok: false, error: (err as Error).message };
	}

	const wordCount = assembledLessons.reduce((sum, l) => sum + l.vocabulary.length, 0);
	return {
		ok: true,
		filename: `${pack.id}.json`,
		json: JSON.stringify(candidate, null, '\t') + '\n',
		wordCount
	};
}

export function downloadPackJson(result: Extract<ExportResult, { ok: true }>): void {
	const blob = new Blob([result.json], { type: 'application/json' });
	const url = URL.createObjectURL(blob);
	const a = document.createElement('a');
	a.href = url;
	a.download = result.filename;
	document.body.appendChild(a);
	a.click();
	document.body.removeChild(a);
	URL.revokeObjectURL(url);
}
