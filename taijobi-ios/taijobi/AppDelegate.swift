import UIKit

/// Bridges iOS's background URLSession lifecycle into the SwiftUI app.
///
/// When a `URLSessionConfiguration.background(...)` task completes while
/// the app is suspended or terminated, iOS launches the app in the
/// background and calls `application(_:handleEventsForBackgroundURLSession:
/// completionHandler:)` with a one-shot completion handler. The
/// background session's delegate fires its callbacks, and at the end we
/// must invoke that handler so iOS knows it's safe to re-suspend the app.
///
/// SwiftUI doesn't expose this hook through the `App` protocol, so we
/// attach a UIApplicationDelegate via `@UIApplicationDelegateAdaptor` in
/// `taijobiApp.swift` and forward the stored handler from inside
/// `BackgroundDownloader.urlSessionDidFinishEvents(...)`.
final class AppDelegate: NSObject, UIApplicationDelegate {
    /// Stashed by `application(_:handleEventsForBackgroundURLSession:...)`
    /// and called by the BackgroundDownloader once all pending delegate
    /// events have been processed. Strictly accessed on the main queue.
    static var backgroundCompletionHandler: (() -> Void)?

    func application(
        _ application: UIApplication,
        handleEventsForBackgroundURLSession identifier: String,
        completionHandler: @escaping () -> Void
    ) {
        // Stash the handler so the BackgroundDownloader can fire it once
        // the URLSession finishes draining its queue.
        Self.backgroundCompletionHandler = completionHandler
        // Force-initialise the downloader so its lazy URLSession re-attaches
        // to the system identifier — without this, iOS has events ready but
        // there's nobody to deliver them to and the app's background time
        // window expires unused.
        _ = BackgroundDownloader.shared
    }
}
