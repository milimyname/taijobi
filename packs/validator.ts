// Shared validator for taijobi pack JSONs. Zero runtime deps.
//
// Imported by:
//   scripts/generate-catalog.ts    — strict, build-time gate on packs/official + packs/community
//   taijobi-sync/src/mcp-tools.ts  — partial, runtime id + language_pair checks in install_pack
//
// Validators throw on the first bad field with `path: reason`. The MCP write
// tool (install_pack) intentionally stays lenient on `translation` so Claude
// can capture partially-known words mid-learning; the strict `validatePack`
// only runs at the community-export boundary.

// ── Types ──────────────────────────────────────────────────────────────────

export type VocabularyItem = { word: string; pinyin?: string; translation: string };
export type Lesson = {
	id: string;
	title?: string;
	sort_order: number;
	vocabulary: VocabularyItem[];
};
export type Pack = {
	id: string;
	name: string;
	version: number;
	language_pair: string;
	description?: string;
	lessons: Lesson[];
};
export type Tag = 'official' | 'community' | 'personal';
export type DictionaryEntry = {
	id: string;
	kind: 'dictionary';
	tag: Tag;
	name: string;
	language_pair: string;
	size_mb: number;
	description: string;
};
export type ContentCatalogEntry = {
	id: string;
	kind: 'content';
	tag: Tag;
	name: string;
	language_pair: string;
	word_count: number;
	description: string;
};
export type CatalogEntry = DictionaryEntry | ContentCatalogEntry;

// ── Constants ──────────────────────────────────────────────────────────────

export const ID_REGEX = /^[a-z0-9][a-z0-9-]*$/;
export const LANG_REGEX = /^[a-z]{2}(-[a-z]{2})?$/;
export const TAGS: readonly Tag[] = ['official', 'community', 'personal'];

// JSON Schema committed to packs/schema.json for contributors' IDE validation.
// Kept in sync by hand with validatePack below.
export const PACK_JSON_SCHEMA = {
	$schema: 'https://json-schema.org/draft/2020-12/schema',
	type: 'object',
	properties: {
		id: { type: 'string', pattern: '^[a-z0-9][a-z0-9-]*$' },
		name: { type: 'string', minLength: 1 },
		version: { type: 'integer', exclusiveMinimum: 0, maximum: 9007199254740991 },
		language_pair: { type: 'string', pattern: '^[a-z]{2}(-[a-z]{2})?$' },
		description: { type: 'string' },
		lessons: {
			minItems: 1,
			type: 'array',
			items: {
				type: 'object',
				properties: {
					id: { type: 'string', pattern: '^[a-z0-9][a-z0-9-]*$' },
					title: { type: 'string' },
					sort_order: { type: 'integer', minimum: 0, maximum: 9007199254740991 },
					vocabulary: {
						minItems: 1,
						type: 'array',
						items: {
							type: 'object',
							properties: {
								word: { type: 'string', minLength: 1 },
								pinyin: { type: 'string' },
								translation: { type: 'string', minLength: 1 },
							},
							required: ['word', 'translation'],
							additionalProperties: false,
						},
					},
				},
				required: ['id', 'sort_order', 'vocabulary'],
				additionalProperties: false,
			},
		},
	},
	required: ['id', 'name', 'version', 'language_pair', 'lessons'],
	additionalProperties: false,
} as const;

// ── Validators ─────────────────────────────────────────────────────────────

function fail(path: string, reason: string): never {
	throw new Error(`${path || '(root)'}: ${reason}`);
}

function str(v: unknown, path: string, regex?: RegExp, allowEmpty = false): string {
	if (typeof v !== 'string') fail(path, 'expected string');
	if (!allowEmpty && v.length === 0) fail(path, 'must not be empty');
	if (regex && !regex.test(v)) fail(path, `must match ${regex.source}`);
	return v;
}

function optStr(v: unknown, path: string): string | undefined {
	return v === undefined ? undefined : str(v, path, undefined, true);
}

function int(v: unknown, path: string, min: number): number {
	if (typeof v !== 'number' || !Number.isInteger(v) || v < min) {
		fail(path, `expected integer >= ${min}`);
	}
	return v as number;
}

function posNum(v: unknown, path: string): number {
	if (typeof v !== 'number' || !Number.isFinite(v) || v <= 0) {
		fail(path, 'expected positive number');
	}
	return v;
}

function obj(v: unknown, path: string, allowed: readonly string[]): Record<string, unknown> {
	if (typeof v !== 'object' || v === null || Array.isArray(v)) fail(path, 'expected object');
	const o = v as Record<string, unknown>;
	for (const k of Object.keys(o)) {
		if (!allowed.includes(k)) fail(`${path}${path ? '.' : ''}${k}`, 'unknown field');
	}
	return o;
}

function nonEmptyArray<T>(
	v: unknown,
	path: string,
	each: (item: unknown, itemPath: string) => T,
): T[] {
	if (!Array.isArray(v)) fail(path, 'expected array');
	if (v.length === 0) fail(path, 'must have at least one entry');
	return v.map((x, i) => each(x, `${path}[${i}]`));
}

export function validatePack(v: unknown): Pack {
	const o = obj(v, '', ['id', 'name', 'version', 'language_pair', 'description', 'lessons']);
	return {
		id: str(o.id, 'id', ID_REGEX),
		name: str(o.name, 'name'),
		version: int(o.version, 'version', 1),
		language_pair: str(o.language_pair, 'language_pair', LANG_REGEX),
		description: optStr(o.description, 'description'),
		lessons: nonEmptyArray(o.lessons, 'lessons', (item, p) => {
			const l = obj(item, p, ['id', 'title', 'sort_order', 'vocabulary']);
			return {
				id: str(l.id, `${p}.id`, ID_REGEX),
				title: optStr(l.title, `${p}.title`),
				sort_order: int(l.sort_order, `${p}.sort_order`, 0),
				vocabulary: nonEmptyArray(l.vocabulary, `${p}.vocabulary`, (wItem, wp) => {
					const w = obj(wItem, wp, ['word', 'pinyin', 'translation']);
					return {
						word: str(w.word, `${wp}.word`),
						pinyin: optStr(w.pinyin, `${wp}.pinyin`),
						translation: str(w.translation, `${wp}.translation`),
					};
				}),
			};
		}),
	};
}

export function validateDictionaries(v: unknown): DictionaryEntry[] {
	if (!Array.isArray(v)) fail('', 'expected array');
	return v.map((item, i) => {
		const p = `[${i}]`;
		const o = obj(item, p, [
			'id',
			'kind',
			'tag',
			'name',
			'language_pair',
			'size_mb',
			'description',
		]);
		if (o.kind !== 'dictionary') fail(`${p}.kind`, 'must be "dictionary"');
		if (typeof o.tag !== 'string' || !TAGS.includes(o.tag as Tag)) {
			fail(`${p}.tag`, `must be one of ${TAGS.join(' | ')}`);
		}
		return {
			id: str(o.id, `${p}.id`, ID_REGEX),
			kind: 'dictionary' as const,
			tag: o.tag as Tag,
			name: str(o.name, `${p}.name`),
			language_pair: str(o.language_pair, `${p}.language_pair`, LANG_REGEX),
			size_mb: posNum(o.size_mb, `${p}.size_mb`),
			description: str(o.description, `${p}.description`, undefined, true),
		};
	});
}
