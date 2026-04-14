/**
 * Centralized configuration — all URLs, keys, and constants in one place.
 */

// --- Sync API ---
export const SYNC_API_URL = (() => {
	if (typeof window === 'undefined') return 'https://sync.taijobi.com';
	const host = window.location.hostname;
	if (
		host === 'localhost' ||
		host === '127.0.0.1' ||
		host.startsWith('192.168.') ||
		host.startsWith('10.') ||
		/^172\.(1[6-9]|2\d|3[01])\./.test(host)
	) {
		return `http://${host}:8788`;
	}
	return 'https://sync.taijobi.com';
})();

// --- GitHub ---
export const RELEASES_URL = 'https://github.com/milimyname/taijobi/releases';
export const GITHUB_RELEASES_API = 'https://api.github.com/repos/milimyname/taijobi/releases';

// --- LocalStorage keys ---
export const LS_SYNC_KEY = 'taijobi_sync_key';
export const LS_SYNC_LAST_TS = 'taijobi_sync_last_ts';
export const LS_LAST_VERSION = 'taijobi-last-version';
export const LS_CHANGELOG = 'taijobi_changelog';
export const LS_THEME = 'taijobi_theme';
export const LS_ONBOARDED = 'taijobi_onboarded';
export const LS_SEARCH_HISTORY = 'taijobi_search_history';
export const LS_FEATURES = 'taijobi_features';
export const LS_SQL_HISTORY = 'taijobi_sql_history';

// --- SessionStorage keys ---
export const SS_DRILL_SESSION = 'taijobi_drill_session';

// --- Feature flags ---
// Map of flag key → default enabled state. Empty by default; add entries
// when you want to dark-launch something (e.g. an experimental drill mode).
// The DevTools Flags tab renders a toggle for every key listed here.
export const DEFAULT_FEATURES: Record<string, boolean> = {};
