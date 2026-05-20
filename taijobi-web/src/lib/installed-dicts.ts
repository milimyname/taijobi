/**
 * Tracks which dictionaries the user *intends* to have installed.
 *
 * The OPFS + WASM-loaded state tells us what's currently usable, but says
 * nothing about user intent — if an update download aborts mid-flight and
 * the old OPFS file is already deleted, the next launch can't distinguish
 * "user never installed this" from "user lost their install". A small LS
 * marker, written on every successful download and on every successful
 * boot-time load, closes that gap so DictUpdateBanner can re-prompt.
 */
import { LS_INSTALLED_DICTS } from './config';

export type DictKind = 'zh' | 'en' | 'de';

const ALL: DictKind[] = ['zh', 'en', 'de'];

export function getInstalledDicts(): DictKind[] {
	if (typeof localStorage === 'undefined') return [];
	try {
		const raw = localStorage.getItem(LS_INSTALLED_DICTS);
		if (!raw) return [];
		const arr = JSON.parse(raw);
		if (!Array.isArray(arr)) return [];
		return arr.filter((k): k is DictKind => ALL.includes(k as DictKind));
	} catch {
		return [];
	}
}

function setInstalledDicts(kinds: DictKind[]): void {
	if (typeof localStorage === 'undefined') return;
	localStorage.setItem(LS_INSTALLED_DICTS, JSON.stringify([...new Set(kinds)]));
}

export function markDictInstalled(kind: DictKind): void {
	const cur = getInstalledDicts();
	if (cur.includes(kind)) return;
	setInstalledDicts([...cur, kind]);
}

export function markDictUninstalled(kind: DictKind): void {
	setInstalledDicts(getInstalledDicts().filter((k) => k !== kind));
}
