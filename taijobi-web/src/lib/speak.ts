/**
 * Text-to-speech using the browser's SpeechSynthesis API.
 *
 * Language detection is delegated to the Zig `hanzi_detect_language`
 * export so TS + Swift + lexicon insert all agree on which voice to
 * pick. A tiny inline fallback covers the window where the older WASM
 * bundle hasn't been re-fetched from cache yet.
 */

import { detectLanguage } from './wasm';

const LANG_MAP: Record<string, string> = {
	zh: 'zh-CN',
	de: 'de-DE',
	en: 'en-US',
	ar: 'ar-SA',
	ja: 'ja-JP',
	ko: 'ko-KR',
	fr: 'fr-FR',
	es: 'es-ES',
	ru: 'ru-RU'
};

/** Single source of truth lives in libtaijobi/src/lang.zig. Falls back
 *  to a coarse heuristic only when the WASM export isn't loaded yet. */
export function detectSpeakLang(text: string): string {
	const zigGuess = detectLanguage(text);
	if (zigGuess) return zigGuess;
	const t = text.trim();
	if (!t) return 'en';
	if (/[一-鿿㐀-䶿]/.test(t)) return 'zh';
	if (/[؀-ۿ]/.test(t)) return 'ar';
	if (/[äöüÄÖÜß]/.test(t)) return 'de';
	return 'en';
}

export function speak(text: string, language: string | 'auto' = 'auto'): void {
	if (!('speechSynthesis' in window)) return;

	const lang = language === 'auto' ? detectSpeakLang(text) : language;

	window.speechSynthesis.cancel();

	const utterance = new SpeechSynthesisUtterance(text);
	utterance.lang = LANG_MAP[lang] ?? 'en-US';
	utterance.rate = 0.85;

	const voices = window.speechSynthesis.getVoices();
	const match = voices.find((v) => v.lang.startsWith(utterance.lang.split('-')[0]));
	if (match) utterance.voice = match;

	window.speechSynthesis.speak(utterance);
}

export function canSpeak(): boolean {
	return 'speechSynthesis' in window;
}
