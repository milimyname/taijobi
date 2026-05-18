import Foundation

/// Centralized constants — URLs, App Group identifier, UserDefaults keys.
/// Mirrors taijobi-web/src/lib/config.ts for the shared concepts.
enum TaijobiConfig {
    /// App Group container — shared between the main app, share extension,
    /// and widget. The SQLite database lives inside this container so all
    /// three targets see the same data without IPC.
    static let appGroup = "group.com.taijobi.app"

    #if DEBUG && targetEnvironment(simulator)
    static let syncBaseURL = "http://localhost:8787"
    #else
    static let syncBaseURL = "https://sync.taijobi.com"
    #endif

    /// UserDefaults keys (kept in App Group defaults so share/widget see them).
    static let udSyncKey = "taijobi_sync_key"
    static let udSyncLastTS = "taijobi_sync_last_ts"
}
