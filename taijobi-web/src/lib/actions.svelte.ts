/**
 * Command palette action registry.
 */
import { goto } from '$app/navigation';
import { themeStore } from './theme.svelte';
import { onboardingStore } from './onboarding.svelte';
import { isSyncEnabled, syncFull, getSyncKey } from './sync';
import { toastStore } from './toast.svelte';
import { exportCsv } from './wasm';
import { FAQ_ENTRIES } from './commandPalette.svelte';

export interface PaletteAction {
	id: string;
	label: string;
	icon: string;
	group: string;
	keywords: string[];
	handler: () => void | Promise<void>;
	danger?: boolean;
	enabled?: () => boolean;
}

function downloadText(filename: string, content: string, mime = 'text/tab-separated-values'): void {
	const blob = new Blob([content], { type: mime });
	const url = URL.createObjectURL(blob);
	const a = document.createElement('a');
	a.href = url;
	a.download = filename;
	a.click();
	URL.revokeObjectURL(url);
}

async function clearOpfsDir(name: string): Promise<void> {
	if (typeof navigator === 'undefined' || !('storage' in navigator)) return;
	try {
		const root = await navigator.storage.getDirectory();
		await (root as FileSystemDirectoryHandle).removeEntry(name, { recursive: true });
	} catch {
		/* ignore */
	}
}

const FAQ_ACTIONS: PaletteAction[] = FAQ_ENTRIES.map((f) => ({
	id: `faq-${f.id}`,
	label: f.q,
	icon: 'help',
	group: 'FAQ',
	keywords: ['faq', 'hilfe', 'help', ...f.keywords],
	handler: () => goto(`/about#${f.id}`)
}));

export function getActions(): PaletteAction[] {
	return [
		// Navigation
		{
			id: 'nav-home',
			label: 'Start',
			icon: 'home',
			group: 'Navigation',
			keywords: ['start', 'home', 'dashboard'],
			handler: () => goto('/home')
		},
		{
			id: 'nav-drill',
			label: 'Üben',
			icon: 'school',
			group: 'Navigation',
			keywords: ['drill', 'üben', 'practice'],
			handler: () => goto('/drill')
		},
		{
			id: 'nav-packs',
			label: 'Pakete',
			icon: 'inventory_2',
			group: 'Navigation',
			keywords: ['packs', 'pakete'],
			handler: () => goto('/packs')
		},
		{
			id: 'nav-lex',
			label: 'Wörter',
			icon: 'style',
			group: 'Navigation',
			keywords: ['lexicon', 'lexikon', 'wörter', 'dictionary', 'wörterbuch'],
			handler: () => goto('/lexicon')
		},
		{
			id: 'nav-chars',
			label: 'Zeichen',
			icon: 'translate',
			group: 'Navigation',
			keywords: ['characters', 'zeichen'],
			handler: () => goto('/characters')
		},
		{
			id: 'nav-settings',
			label: 'Einstellungen',
			icon: 'settings',
			group: 'Navigation',
			keywords: ['settings', 'einstellungen'],
			handler: () => goto('/settings')
		},
		{
			id: 'nav-about',
			label: 'Über',
			icon: 'info',
			group: 'Navigation',
			keywords: ['about', 'über'],
			handler: () => goto('/about')
		},

		// Drill
		{
			id: 'drill-start',
			label: 'Drill starten',
			icon: 'play_arrow',
			group: 'Drill',
			keywords: ['drill', 'start'],
			handler: () => goto('/drill')
		},
		{
			id: 'drill-mixed',
			label: 'Alles gemischt',
			icon: 'shuffle',
			group: 'Drill',
			keywords: ['mixed', 'gemischt', 'alles'],
			handler: () => goto('/drill?filter=all')
		},

		// Daten
		{
			id: 'data-export-csv',
			label: 'CSV exportieren',
			icon: 'download',
			group: 'Daten',
			keywords: ['csv', 'export', 'tsv'],
			handler: () => {
				try {
					const tsv = exportCsv();
					downloadText('taijobi-export.tsv', tsv);
					toastStore.show('CSV exportiert');
				} catch (e) {
					toastStore.show('Export fehlgeschlagen');
					console.error(e);
				}
			}
		},
		{
			id: 'data-packs',
			label: 'Pakete verwalten',
			icon: 'inventory_2',
			group: 'Daten',
			keywords: ['packs', 'pakete'],
			handler: () => goto('/packs')
		},
		{
			id: 'data-dicts',
			label: 'Wörterbücher installieren',
			icon: 'download',
			group: 'Daten',
			keywords: ['dictionary', 'install', 'wörterbuch', 'pakete'],
			handler: () => goto('/packs?kind=dictionary')
		},

		// Theme
		{
			id: 'theme-light',
			label: 'Hell',
			icon: 'light_mode',
			group: 'Theme',
			keywords: ['light', 'hell', 'theme'],
			handler: () => themeStore.set('light')
		},
		{
			id: 'theme-dark',
			label: 'Dunkel',
			icon: 'dark_mode',
			group: 'Theme',
			keywords: ['dark', 'dunkel', 'theme'],
			handler: () => themeStore.set('dark')
		},
		{
			id: 'theme-system',
			label: 'System',
			icon: 'contrast',
			group: 'Theme',
			keywords: ['system', 'auto', 'theme'],
			handler: () => themeStore.set('system')
		},

		// Sync
		{
			id: 'sync-now',
			label: 'Jetzt synchronisieren',
			icon: 'sync',
			group: 'Sync',
			keywords: ['sync', 'synchronisieren'],
			enabled: isSyncEnabled,
			handler: async () => {
				const key = getSyncKey();
				if (!key) {
					toastStore.show('Kein Sync-Schlüssel');
					return;
				}
				try {
					const r = await syncFull(key);
					toastStore.show(`Sync OK (${r.pulled} ↓ / ${r.pushed} ↑)`);
				} catch (e) {
					toastStore.show('Sync fehlgeschlagen');
					console.error(e);
				}
			}
		},
		{
			id: 'sync-copy',
			label: 'Sync-Schlüssel kopieren',
			icon: 'content_copy',
			group: 'Sync',
			keywords: ['sync', 'key', 'kopieren'],
			enabled: isSyncEnabled,
			handler: async () => {
				const key = getSyncKey() ?? '';
				try {
					await navigator.clipboard.writeText(key);
					toastStore.show('Schlüssel kopiert');
				} catch {
					toastStore.show('Kopieren fehlgeschlagen');
				}
			}
		},
		{
			id: 'sync-qr',
			label: 'Sync-Schlüssel als QR-Code',
			icon: 'qr_code_2',
			group: 'Sync',
			keywords: ['sync', 'key', 'qr', 'qrcode', 'backup', 'sichern'],
			enabled: isSyncEnabled,
			handler: () => goto('/settings?show=qr')
		},
		{
			id: 'sync-download',
			label: 'Sync-Schlüssel als Datei sichern',
			icon: 'download',
			group: 'Sync',
			keywords: ['sync', 'key', 'backup', 'sichern', 'download', 'datei'],
			enabled: isSyncEnabled,
			handler: () => {
				const key = getSyncKey();
				if (!key) {
					toastStore.show('Kein Sync-Schlüssel');
					return;
				}
				const stamp = new Date().toISOString().slice(0, 10);
				const body = `Taijobi Sync-Schlüssel
Erstellt: ${new Date().toLocaleString('de-DE')}

${key}

Diesen Schlüssel sicher aufbewahren. Er ist deine Identität —
auf jedem Gerät, das du verbinden willst, fügst du genau diesen
Schlüssel ein. Ohne ihn lassen sich verschlüsselte Daten nicht
wiederherstellen.
`;
				downloadText(`taijobi-sync-key-${stamp}.txt`, body, 'text/plain');
				localStorage.setItem('taijobi_key_backed_up', '1');
				toastStore.show('Schlüssel heruntergeladen');
			}
		},
		{
			id: 'sync-enable',
			label: 'Sync aktivieren',
			icon: 'sync',
			group: 'Sync',
			keywords: ['sync', 'aktivieren', 'enable', 'einrichten'],
			enabled: () => !isSyncEnabled(),
			handler: () => goto('/settings?show=sync-info')
		},

		// Onboarding
		{
			id: 'onboarding-restart',
			label: 'Tour erneut zeigen',
			icon: 'explore',
			group: 'Onboarding',
			keywords: ['tour', 'onboarding'],
			handler: () => {
				onboardingStore.reset();
				toastStore.show('Tour zurückgesetzt');
			}
		},

		// Danger Zone
		{
			id: 'danger-clear-dicts',
			label: 'Wörterbuch-Daten löschen',
			icon: 'delete',
			group: 'Danger Zone',
			keywords: ['reset', 'löschen', 'danger', 'dict'],
			danger: true,
			handler: async () => {
				await clearOpfsDir('dictionary-data');
				await clearOpfsDir('chinese-data');
				toastStore.show('Wörterbuch-Daten gelöscht — neu laden');
				setTimeout(() => location.reload(), 800);
			}
		},
		...FAQ_ACTIONS,

		{
			id: 'danger-full-reset',
			label: 'Vollständiger Reset',
			icon: 'delete_forever',
			group: 'Danger Zone',
			keywords: ['reset', 'löschen', 'danger', 'full'],
			danger: true,
			handler: async () => {
				try {
					localStorage.clear();
					sessionStorage.clear();
				} catch {
					/* ignore */
				}
				await clearOpfsDir('dictionary-data');
				await clearOpfsDir('chinese-data');
				try {
					const root = await navigator.storage.getDirectory();
					await (root as FileSystemDirectoryHandle).removeEntry('taijobi.db');
				} catch {
					/* ignore */
				}
				toastStore.show('Vollständiger Reset — neu laden');
				setTimeout(() => location.reload(), 800);
			}
		}
	];
}
