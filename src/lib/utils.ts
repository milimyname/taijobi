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

export const getFlashcardHeight = (width: number, height: number) =>
	(width > IS_DESKTOP ? CANVAS_LG_HEIGHT : width < XM_SMALL_SCREEN ? height * 0.6 : height * 0.6) +
	2;

export const getFlashcardWidth = (width: number) =>
	(width > IS_DESKTOP ? CANVAS_LG_WIDTH : width < XM_SMALL_SCREEN ? CANVAS_SM_WIDTH : width * 0.9) +
	2;

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
