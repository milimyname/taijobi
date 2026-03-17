/**
 * Text-to-speech using the browser's SpeechSynthesis API.
 * Supports Chinese, German, and English with automatic voice selection.
 */

const LANG_MAP: Record<string, string> = {
	zh: 'zh-CN',
	de: 'de-DE',
	en: 'en-US'
};

export function speak(text: string, language: string = 'zh'): void {
	if (!('speechSynthesis' in window)) return;

	// Cancel any ongoing speech
	window.speechSynthesis.cancel();

	const utterance = new SpeechSynthesisUtterance(text);
	utterance.lang = LANG_MAP[language] ?? 'en-US';
	utterance.rate = 0.85;

	// Try to find a matching voice
	const voices = window.speechSynthesis.getVoices();
	const match = voices.find((v) => v.lang.startsWith(utterance.lang.split('-')[0]));
	if (match) utterance.voice = match;

	window.speechSynthesis.speak(utterance);
}

export function canSpeak(): boolean {
	return 'speechSynthesis' in window;
}
