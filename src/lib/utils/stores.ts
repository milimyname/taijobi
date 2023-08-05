import { writable } from 'svelte/store';

export const showNav = writable(false);
export const showAppNav = writable(false);
export const isLongPress = writable(false);
export const animateSVG = writable(true);
export const showProgressSlider = writable(false);
export const strokeColor = writable('#000000');
export const innerWidthStore = writable(0);
export const lastPoint = writable({ x: 0, y: 0 });
export const hiraganaStore = writable([
	'あ',
	'い',
	'う',
	'え',
	'お',
	'か',
	'き',
	'く',
	'け',
	'こ',
	'さ',
	'し',
	'す',
	'せ',
	'そ',
	'た',
	'ち',
	'つ',
	'て',
	'と',
	'な',
	'に',
	'ぬ',
	'ね',
	'の',
	'は',
	'ひ',
	'ふ',
	'へ',
	'ほ',
	'ま',
	'み',
	'む',
	'め',
	'も',
	'や',
	'ゆ',
	'よ',
	'ら',
	'り',
	'る',
	'れ',
	'ろ',
	'わ',
	'を',
	'ん'
]);
export const currentHiragana = writable('あ');
export const progressSlider = writable(1);
