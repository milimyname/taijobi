/**
 * Cmd+K command palette open/close store + FAQ entries.
 *
 * FAQ_ENTRIES mirror the questions on /about and are surfaced in the palette
 * as navigable actions (group: "FAQ"). Selecting one navigates to /about#faq-id
 * which auto-opens the matching <details> via the afterNavigate hook on the
 * about page.
 */
class PaletteStore {
	open = $state(false);

	show(): void {
		this.open = true;
	}

	hide(): void {
		this.open = false;
	}

	toggle(): void {
		this.open = !this.open;
	}
}

export const paletteStore = new PaletteStore();

export interface FaqEntry {
	id: string;
	q: string;
	keywords: string[];
}

/**
 * Keep these in sync with the `faqs` array in src/routes/(app)/about/+page.svelte.
 * Each entry's `id` must match the corresponding <details id="..."> on the about page.
 */
export const FAQ_ENTRIES: FaqEntry[] = [
	{
		id: 'faq-was-ist',
		q: 'Was ist Taijobi?',
		keywords: ['taijobi', 'was', 'engine', 'libtaijobi']
	},
	{
		id: 'faq-rewrite',
		q: 'Warum wurde Taijobi neu geschrieben?',
		keywords: ['rewrite', 'neu', 'alt', 'old', 'history', 'geschichte', 'libtaijobi', 'wimg']
	},
	{
		id: 'faq-fsrs',
		q: 'Was ist FSRS und wie funktioniert das Üben?',
		keywords: ['fsrs', 'spaced', 'repetition', 'üben', 'algorithmus']
	},
	{
		id: 'faq-sicherheit',
		q: 'Sind meine Daten sicher?',
		keywords: ['sicher', 'privacy', 'security', 'datenschutz']
	},
	{
		id: 'faq-offline',
		q: 'Funktioniert Taijobi offline?',
		keywords: ['offline', 'pwa', 'internet']
	},
	{
		id: 'faq-pakete',
		q: 'Welche Pakete gibt es?',
		keywords: ['pakete', 'hsk', 'lóng', 'long', 'csv', 'apkg']
	},
	{
		id: 'faq-lexikon',
		q: 'Was ist das persönliche Lexikon?',
		keywords: ['lexikon', 'lexicon', 'wörter']
	},
	{
		id: 'faq-wörterbücher',
		q: 'Welche Wörterbücher sind verfügbar?',
		keywords: ['wörterbücher', 'cedict', 'wiktionary', 'dictionary']
	},
	{
		id: 'faq-zeichen',
		q: 'Was kann die Zeichen-Detailseite?',
		keywords: ['zeichen', 'character', 'radikal', 'strichfolge']
	},
	{
		id: 'faq-arabisch',
		q: 'Werden auch andere Sprachen unterstützt?',
		keywords: ['arabisch', 'arabic', 'sprachen', 'languages', 'rtl']
	},
	{
		id: 'faq-self-assess',
		q: 'Was ist Self-Assessment-Modus?',
		keywords: ['self', 'assessment', 'aufdecken', 'definition']
	},
	{
		id: 'faq-vorziehen',
		q: 'Was ist „Vorziehen"?',
		keywords: ['vorziehen', 'pull', 'forward', 'upcoming']
	},
	{
		id: 'faq-sync',
		q: 'Wie synchronisiere ich zwischen Geräten?',
		keywords: ['sync', 'synchronisieren', 'geräte', 'schlüssel']
	},
	{
		id: 'faq-shortcuts',
		q: 'Gibt es Tastenkürzel?',
		keywords: ['shortcuts', 'tastenkürzel', 'keyboard', 'vim']
	},
	{
		id: 'faq-darkmode',
		q: 'Gibt es einen Dark Mode?',
		keywords: ['dark', 'mode', 'dunkel', 'theme']
	},
	{
		id: 'faq-import',
		q: 'Wie importiere ich aus Anki/Quizlet?',
		keywords: ['import', 'anki', 'quizlet', 'csv', 'apkg']
	},
	{
		id: 'faq-export',
		q: 'Kann ich meine Karten exportieren?',
		keywords: ['export', 'csv', 'tsv', 'karten']
	},
	{
		id: 'faq-stats',
		q: 'Was zeigt die Statistik?',
		keywords: ['stats', 'statistik', 'streak', 'heatmap']
	},
	{
		id: 'faq-kostenlos',
		q: 'Ist Taijobi kostenlos?',
		keywords: ['kostenlos', 'free', 'open', 'source']
	},
	{ id: 'faq-ios', q: 'Gibt es eine iOS-App?', keywords: ['ios', 'iphone', 'swiftui', 'app'] },
	{ id: 'faq-android', q: 'Gibt es eine Android-App?', keywords: ['android', 'app'] },
	{
		id: 'faq-beitragen',
		q: 'Wie kann ich beitragen?',
		keywords: ['beitragen', 'contribute', 'github', 'open', 'source']
	}
];
