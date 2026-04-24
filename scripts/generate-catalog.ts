#!/usr/bin/env bun
/**
 * Reads packs/official/, packs/community/, and packs/dictionaries.json;
 * validates everything via ../packs/validator.ts; emits:
 *   packs/schema.json                          — JSON Schema for IDE validation
 *   taijobi-web/static/packs/catalog.json      — merged dicts + content packs
 *   taijobi-web/static/packs/<id>.json         — byte copy of each pack source
 *
 * Flags:
 *   --check    don't write; exit 1 if output would differ from committed files
 */
import { readFileSync, readdirSync, existsSync, mkdirSync, writeFileSync } from 'node:fs';
import { join, basename, relative, resolve } from 'node:path';

import {
	PACK_JSON_SCHEMA,
	validateDictionaries,
	validatePack,
	type CatalogEntry,
	type DictionaryEntry,
	type Pack,
} from '../packs/validator.ts';

const REPO = resolve(import.meta.dirname, '..');
const PACKS_DIR = join(REPO, 'packs');
const OUT_DIR = join(REPO, 'taijobi-web/static/packs');

const check = process.argv.includes('--check');

type DiscoveredPack = { path: string; pack: Pack; tag: 'official' | 'community' };

function main(): void {
	const errors: string[] = [];

	const dicts = loadDictionaries(errors);
	const packs = discoverPacks(errors);

	const allIds = [...dicts.map((d) => d.id), ...packs.map((p) => p.pack.id)];
	const dupes = [...new Set(allIds.filter((id, i) => allIds.indexOf(id) !== i))];
	if (dupes.length > 0) errors.push(`duplicate ids: ${dupes.join(', ')}`);

	if (errors.length > 0) {
		console.error('Pack validation failed:');
		for (const e of errors) console.error(`  ✗ ${e}`);
		process.exit(1);
	}

	const catalog = buildCatalog(dicts, packs);

	// Committed — `--check` verifies these match the regenerated content.
	const committedOutputs: Array<[string, string]> = [
		[join(PACKS_DIR, 'schema.json'), jsonStringify(PACK_JSON_SCHEMA)],
	];

	// Build artifacts — gitignored; always (re)written in write mode, never checked.
	const artifactOutputs: Array<[string, string]> = [
		[join(OUT_DIR, 'catalog.json'), jsonStringify(catalog)],
		...packs.map(
			({ path, pack }): [string, string] => [
				join(OUT_DIR, `${pack.id}.json`),
				readFileSync(path, 'utf8'),
			],
		),
	];

	if (check) {
		const diffs: string[] = [];
		for (const [path, expected] of committedOutputs) {
			const current = existsSync(path) ? readFileSync(path, 'utf8') : '';
			if (current.trim() !== expected.trim()) {
				diffs.push(`${relative(REPO, path)} is stale`);
			}
		}
		if (diffs.length > 0) {
			console.error('Catalog generation is out of date:');
			for (const d of diffs) console.error(`  ✗ ${d}`);
			console.error('\nRun: bun scripts/generate-catalog.ts');
			process.exit(1);
		}
		console.log(`✓ catalog is current (${packs.length} packs, ${dicts.length} dicts)`);
		return;
	}

	if (!existsSync(PACKS_DIR)) mkdirSync(PACKS_DIR, { recursive: true });
	if (!existsSync(OUT_DIR)) mkdirSync(OUT_DIR, { recursive: true });
	for (const [path, content] of [...committedOutputs, ...artifactOutputs]) {
		const normalized = content.endsWith('\n') ? content : `${content}\n`;
		writeFileSync(path, normalized);
	}
	console.log(`✓ wrote catalog: ${packs.length} packs, ${dicts.length} dicts`);
}

function loadDictionaries(errors: string[]): DictionaryEntry[] {
	const path = join(PACKS_DIR, 'dictionaries.json');
	if (!existsSync(path)) {
		errors.push('packs/dictionaries.json: missing');
		return [];
	}
	let parsed: unknown;
	try {
		parsed = JSON.parse(readFileSync(path, 'utf8'));
	} catch (err) {
		errors.push(`packs/dictionaries.json: invalid JSON — ${(err as Error).message}`);
		return [];
	}
	try {
		return validateDictionaries(parsed);
	} catch (err) {
		errors.push(`packs/dictionaries.json: ${(err as Error).message}`);
		return [];
	}
}

function discoverPacks(errors: string[]): DiscoveredPack[] {
	const sources: Array<{ dir: string; tag: 'official' | 'community' }> = [
		{ dir: join(PACKS_DIR, 'official'), tag: 'official' },
		{ dir: join(PACKS_DIR, 'community'), tag: 'community' },
	];

	const discovered: DiscoveredPack[] = [];
	for (const { dir, tag } of sources) {
		if (!existsSync(dir)) continue;
		const files = readdirSync(dir)
			.filter((f) => f.endsWith('.json') && !f.startsWith('.') && f !== 'catalog.json')
			.sort();
		for (const file of files) {
			const full = join(dir, file);
			const rel = relative(REPO, full);
			let parsed: unknown;
			try {
				parsed = JSON.parse(readFileSync(full, 'utf8'));
			} catch (err) {
				errors.push(`${rel}: invalid JSON — ${(err as Error).message}`);
				continue;
			}
			let pack: Pack;
			try {
				pack = validatePack(parsed);
			} catch (err) {
				errors.push(`${rel}: ${(err as Error).message}`);
				continue;
			}
			const stem = basename(file, '.json');
			if (stem !== pack.id) {
				errors.push(`${rel}: filename must be "${pack.id}.json" (matches pack.id)`);
				continue;
			}
			discovered.push({ path: full, pack, tag });
		}
	}
	return discovered;
}

function buildCatalog(dicts: DictionaryEntry[], packs: DiscoveredPack[]): CatalogEntry[] {
	const contentEntries: CatalogEntry[] = packs.map(({ pack, tag }) => ({
		id: pack.id,
		kind: 'content',
		tag,
		name: pack.name,
		language_pair: pack.language_pair,
		word_count: pack.lessons.reduce((sum, l) => sum + l.vocabulary.length, 0),
		description: pack.description ?? '',
	}));
	return [...dicts, ...contentEntries];
}

function jsonStringify(value: unknown): string {
	return JSON.stringify(value, null, '\t');
}

main();
