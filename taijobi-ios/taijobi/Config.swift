import Foundation

/// Centralized constants — URLs, App Group identifier, UserDefaults keys.
/// Mirrors taijobi-web/src/lib/config.ts for the shared concepts.
enum TaijobiConfig {
    /// App Group container — shared between the main app, share extension,
    /// and widget. The SQLite database lives inside this container so all
    /// three targets see the same data without IPC.
    static let appGroup = "group.com.taijobi.app"

    /// Local dev: 8788 is the port `wrangler dev` runs taijobi-sync on
    /// (see taijobi-sync/wrangler.toml). Simulator reaches the host via
    /// `localhost`; a real device needs the Mac's LAN IP — set
    /// `TAIJOBI_SYNC_URL` in the scheme's environment variables to override.
    static let syncBaseURL: String = {
        if let override = ProcessInfo.processInfo.environment["TAIJOBI_SYNC_URL"],
           !override.isEmpty {
            return override
        }
        #if DEBUG && targetEnvironment(simulator)
        return "http://localhost:8788"
        #else
        return "https://sync.taijobi.com"
        #endif
    }()

    /// UserDefaults keys (kept in App Group defaults so share/widget see them).
    static let udSyncKey = "taijobi_sync_key"
    static let udSyncLastTS = "taijobi_sync_last_ts"
}
