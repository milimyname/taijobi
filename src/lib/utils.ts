import { type ClassValue, clsx } from 'clsx';
import { twMerge } from 'tailwind-merge';
import { cubicOut } from 'svelte/easing';
import type { TransitionConfig } from 'svelte/transition';
import { mediaQuery } from 'svelte-legos';
import {
	IS_DESKTOP,
	XM_SMALL_SCREEN,
	CANVAS_LG_HEIGHT,
	CANVAS_LG_WIDTH,
	CANVAS_SM_WIDTH
} from '$lib/utils/constants';
import { isKanji, isKatakana, isHiragana } from 'wanakana';
import { kanji } from '$lib/static/kanji';

// Check if a string does not contain any Japanese characters
export const isNonJapanase = (str: string) => {
	// Split the string into individual characters
	const chars = str.split('');

	// Check each character
	// If any character is a Japanese character, return false
	for (const char of chars) if (isKanji(char) || isKatakana(char) || isHiragana(char)) return false; // Found a Japanese character, so it's not Romaji

	// If no Japanese characters are found, return true
	return true;
};

export function cn(...inputs: ClassValue[]) {
	return twMerge(clsx(inputs));
}

export const isDesktop = mediaQuery('(min-width: 768px)');

// Get 3 random kanji characterS
export const getRandomKanji = () => {
	// Convert to an array
	const kanjiArray = Object.entries(kanji);

	// Get a random index
	const randomIndex = Math.floor(Math.random() * kanjiArray.length);

	// Return the kanji character at the index array of objects with name as key and meaning
	return [
		{
			name: kanjiArray[randomIndex][0],
			meaning: kanjiArray[randomIndex][1].meaning,
			onyomi: kanjiArray[randomIndex][1].onyomi,
			kunyomi: kanjiArray[randomIndex][1].kunyomi,
			id: Math.random().toString(36).substr(2, 9)
		},
		{
			name: kanjiArray[randomIndex + 1][0],
			meaning: kanjiArray[randomIndex + 1][1].meaning,
			onyomi: kanjiArray[randomIndex + 1][1].onyomi,
			kunyomi: kanjiArray[randomIndex + 1][1].kunyomi,
			id: Math.random().toString(36).substr(2, 9)
		},
		{
			name: kanjiArray[randomIndex + 2][0],
			meaning: kanjiArray[randomIndex + 2][1].meaning,
			onyomi: kanjiArray[randomIndex + 2][1].onyomi,
			kunyomi: kanjiArray[randomIndex + 2][1].kunyomi,
			id: Math.random().toString(36).substr(2, 9)
		}
	];
};

export const getFlashcardHeight = (width: number, height: number) =>
	(width > IS_DESKTOP ? CANVAS_LG_HEIGHT : width < XM_SMALL_SCREEN ? height * 0.6 : height * 0.6) +
	2;

export const getFlashcardWidth = (width: number) =>
	(width > IS_DESKTOP ? CANVAS_LG_WIDTH : width < XM_SMALL_SCREEN ? CANVAS_SM_WIDTH : width * 0.9) +
	2;

// Get the platform the user is on
export function getPlatform() {
	if (typeof window === 'undefined') return 'unknown';

	const platform = navigator.platform.toLowerCase();
	if (platform.includes('win')) return 'windows';
	if (platform.includes('mac')) return 'mac';
	if (platform.includes('linux')) return 'linux';
	return 'unknown';
}

// Get the hotkey prefix for the user's platform
export function getHotkeyPrefix() {
	const platform = getPlatform();
	return platform.startsWith('mac') ? '⌘' : 'Ctrl';
}

export const replaceStateWithQuery = (values: Record<string, string>) => {
	const url = new URL(window.location.toString());
	for (const [k, v] of Object.entries(values)) {
		if (!!v) url.searchParams.set(k, v);
		else url.searchParams.delete(k);
	}
	history.replaceState(history.state, '', url);
};

type FlyAndScaleParams = {
	y?: number;
	x?: number;
	start?: number;
	duration?: number;
};

export const flyAndScale = (
	node: Element,
	params: FlyAndScaleParams = { y: -8, x: 0, start: 0.95, duration: 150 }
): TransitionConfig => {
	const style = getComputedStyle(node);
	const transform = style.transform === 'none' ? '' : style.transform;

	const scaleConversion = (valueA: number, scaleA: [number, number], scaleB: [number, number]) => {
		const [minA, maxA] = scaleA;
		const [minB, maxB] = scaleB;

		const percentage = (valueA - minA) / (maxA - minA);
		const valueB = percentage * (maxB - minB) + minB;

		return valueB;
	};

	const styleToString = (style: Record<string, number | string | undefined>): string => {
		return Object.keys(style).reduce((str, key) => {
			if (style[key] === undefined) return str;
			return str + `${key}:${style[key]};`;
		}, '');
	};

	return {
		duration: params.duration ?? 200,
		delay: 0,
		css: (t) => {
			const y = scaleConversion(t, [0, 1], [params.y ?? 5, 0]);
			const x = scaleConversion(t, [0, 1], [params.x ?? 0, 0]);
			const scale = scaleConversion(t, [0, 1], [params.start ?? 0.95, 1]);

			return styleToString({
				transform: `${transform} translate3d(${x}px, ${y}px, 0) scale(${scale})`,
				opacity: t
			});
		},
		easing: cubicOut
	};
};
