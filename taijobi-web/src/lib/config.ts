/**
 * Centralized configuration — all URLs, keys, and constants in one place.
 */

// --- Sync API ---
export const SYNC_API_URL = (() => {
  if (typeof window === "undefined") return "https://sync.taijobi.com";
  const host = window.location.hostname;
  if (
    host === "localhost" ||
    host === "127.0.0.1" ||
    host.startsWith("192.168.") ||
    host.startsWith("10.") ||
    /^172\.(1[6-9]|2\d|3[01])\./.test(host)
  ) {
    return `http://${host}:8788`;
  }
  return "https://sync.taijobi.com";
})();

// --- GitHub ---
export const RELEASES_URL = "https://github.com/milimyname/taijobi/releases";
export const GITHUB_RELEASES_API = "https://api.github.com/repos/milimyname/taijobi/releases";

// --- LocalStorage keys ---
export const LS_SYNC_KEY = "taijobi_sync_key";
export const LS_SYNC_LAST_TS = "taijobi_sync_last_ts";
export const LS_LAST_VERSION = "taijobi-last-version";
export const LS_CHANGELOG = "taijobi_changelog";
export const LS_THEME = "taijobi_theme";
