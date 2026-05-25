import Foundation
import UIKit
import UserNotifications

/// One singleton URLSession backed by `URLSessionConfiguration.background`,
/// shared by every dictionary download. iOS requires background sessions
/// to be created with a stable identifier and a single delegate that
/// outlives any one request — instantiating one per download (the old
/// per-request pattern in DictionaryData) silently drops events when the
/// app suspends.
///
/// Mid-download app suspension / kill is the whole point of moving to
/// this API: iOS keeps the download running through `nsurlsessiond`, then
/// — when the task finishes — re-launches the app (if it was killed)
/// and replays delegate events. We persist a `taskID → file/kind` map in
/// UserDefaults so the relaunched process can still route the bytes to
/// the right App-Group cache file.
@MainActor
final class BackgroundDownloader: NSObject, ObservableObject {
    static let shared = BackgroundDownloader()

    /// Stable identifier — must match across launches so iOS can find the
    /// pending tasks for this session. Changing this string orphans any
    /// in-flight download on the next install.
    private static let sessionId = "com.taijobi.app.dictdownload"

    /// Bumped on every byte-written and every completion so SwiftUI views
    /// observing `DictionaryData` (which mirrors progress here) can
    /// repaint. Kept as a fraction in [0, 1] for the active file only.
    @Published var activeFileProgress: Double = 0
    /// `nil` while idle; the file name currently downloading otherwise.
    /// Set by `enqueue` and cleared on completion (success or failure).
    @Published var activeFile: String?
    @Published var lastError: String?

    /// Each in-flight task knows what file it represents — written to
    /// UserDefaults before `resume()` so a relaunched process can pick up
    /// the right file mapping when the system replays a completion.
    private struct TaskInfo: Codable {
        let file: String
        let kindRaw: String
    }

    /// Continuations awaiting a download — one per active file. Resolved
    /// from the delegate so the foreground caller's
    /// `await BackgroundDownloader.shared.download(...)` unblocks the
    /// moment the file lands on disk. If the app was killed mid-download,
    /// the relaunched process has no continuation; the delegate still
    /// runs (writes the file to cache, posts the notification), the user
    /// just doesn't have an awaiter to satisfy.
    private var continuations: [String: CheckedContinuation<Data, Error>] = [:]
    private var taskInfos: [Int: TaskInfo] = [:]

    /// Lazy so the session isn't created during testing / preview builds
    /// (background sessions assert against the system's `nsurlsessiond`
    /// and crash in non-app contexts). First access — typically from
    /// `enqueue` or from `AppDelegate.handleEventsForBackgroundURLSession`
    /// — instantiates it with `self` as the delegate, which is the only
    /// time iOS lets us register one for a background session.
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.background(withIdentifier: Self.sessionId)
        // Wake the app on completion so we can post the local notification
        // and load bytes into the App-Group cache before re-suspending.
        config.sessionSendsLaunchEvents = true
        // 10-minute wall-clock budget for any single download — same as the
        // old foreground session's `timeoutIntervalForResource`. Background
        // tasks are usually completed by nsurlsessiond opportunistically;
        // this is the upper bound before iOS gives up.
        config.timeoutIntervalForResource = 600
        // Run downloads even on cellular if the user is willing; the
        // marketplace catalog already shows MB sizes so they've consented.
        config.allowsCellularAccess = true
        // .default discretion: iOS may delay over cellular under battery
        // pressure but won't refuse outright. .background here would be
        // strict opportunism — we want the user's tap to start immediately.
        config.isDiscretionary = false
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()

    private override init() {
        super.init()
        // Pull the persisted task ↔ file map back into memory so a
        // relaunched process can resolve the next delegate callback's
        // `task.taskIdentifier` to the right file. The session may
        // already have pending events queued at this point.
        loadTaskInfos()
    }

    // MARK: - Public API

    /// Enqueue a download. Resolves with the downloaded bytes when the
    /// task finishes — *if* this process is still alive at that time.
    /// If the app is killed mid-download, the delegate callbacks fire in
    /// the relaunched process (which writes the bytes to the App-Group
    /// cache + posts a completion notification), but this caller's
    /// continuation goes away with the dead process.
    func download(file: String, kind: DictionaryData.Kind) async throws -> Data {
        // Request notification permission lazily — first download. We
        // don't block on the result; if the user denies, downloads still
        // work, just without a "fertig" ping.
        requestNotificationPermissionIfNeeded()

        let url = URL(string: "https://taijobi.com/data/\(file)")!
        let task = session.downloadTask(with: url)
        let info = TaskInfo(file: file, kindRaw: kind.rawValue)
        taskInfos[task.taskIdentifier] = info
        persistTaskInfos()
        activeFile = file
        activeFileProgress = 0
        lastError = nil

        return try await withCheckedThrowingContinuation { continuation in
            continuations[file] = continuation
            task.resume()
        }
    }

    // MARK: - Persistence

    private static let udTaskInfosKey = "taijobi.bgdownload.taskInfos"

    private func loadTaskInfos() {
        guard let data = UserDefaults.standard.data(forKey: Self.udTaskInfosKey),
              let map = try? JSONDecoder().decode([Int: TaskInfo].self, from: data)
        else { return }
        taskInfos = map
    }

    private func persistTaskInfos() {
        guard let data = try? JSONEncoder().encode(taskInfos) else { return }
        UserDefaults.standard.set(data, forKey: Self.udTaskInfosKey)
    }

    // MARK: - Notifications

    private var permissionRequested = false

    private func requestNotificationPermissionIfNeeded() {
        guard !permissionRequested else { return }
        permissionRequested = true
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    /// Fired from `didFinishDownloadingTo`. Skipped when the app is
    /// foreground — the user can already see the install card flip to
    /// "Geladen", a notification would be noise. When the app is suspended
    /// or terminated, this is the only signal the download finished.
    private func postCompletionNotification(file: String, kind: DictionaryData.Kind) {
        Task { @MainActor in
            // `applicationState` is .active when the user is looking at
            // the app, .inactive during transitions (e.g. control center
            // pulled down), .background when fully backgrounded. Only
            // .active is "definitely don't notify"; the other two warrant
            // a ping since the user has moved on.
            if UIApplication.shared.applicationState == .active { return }
            let content = UNMutableNotificationContent()
            content.title = "\(kind.label)-Wörterbuch fertig"
            content.body = "Du kannst jetzt offline suchen."
            content.sound = .default
            let request = UNNotificationRequest(
                identifier: "taijobi.dict.\(kind.rawValue).\(file)",
                content: content,
                trigger: nil
            )
            try? await UNUserNotificationCenter.current().add(request)
        }
    }
}

// MARK: - URLSession delegates

// Delegate callbacks come in on the URLSession's delegate queue (not
// MainActor). Each method hops to MainActor before touching @Published
// state or the continuations/taskInfos maps.
extension BackgroundDownloader: URLSessionDownloadDelegate {
    nonisolated func urlSession(
        _: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData _: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let fraction = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        let taskId = downloadTask.taskIdentifier
        Task { @MainActor [weak self] in
            guard let self else { return }
            guard let info = self.taskInfos[taskId], info.file == self.activeFile
            else { return }
            self.activeFileProgress = min(max(fraction, 0), 1)
        }
    }

    nonisolated func urlSession(
        _: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        // Read the bytes *here*, on the delegate queue — `location` is a
        // temp file that iOS deletes the moment this method returns.
        // Reading first means even if the MainActor hop is slow, we still
        // have the data.
        let bytes: Data?
        let httpStatus: Int?
        if let http = downloadTask.response as? HTTPURLResponse, http.statusCode != 200 {
            bytes = nil
            httpStatus = http.statusCode
        } else {
            bytes = try? Data(contentsOf: location)
            httpStatus = nil
        }
        let taskId = downloadTask.taskIdentifier
        Task { @MainActor [weak self] in
            guard let self else { return }
            guard let info = self.taskInfos.removeValue(forKey: taskId) else { return }
            self.persistTaskInfos()
            guard let kind = DictionaryData.Kind(rawValue: info.kindRaw) else { return }

            if let status = httpStatus {
                let err = NSError(
                    domain: "taijobi.bgdownload",
                    code: status,
                    userInfo: [NSLocalizedDescriptionKey: "HTTP \(status) für \(info.file)"]
                )
                self.failContinuation(file: info.file, error: err)
                return
            }
            guard let data = bytes else {
                self.failContinuation(
                    file: info.file,
                    error: NSError(
                        domain: "taijobi.bgdownload",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Leere Daten für \(info.file)"]
                    )
                )
                return
            }

            // Write to App-Group cache so `loadCachedOnBoot()` picks it up
            // even when the relaunched process can't load WASM yet (no
            // continuation to await). This makes the cache the source of
            // truth — exactly mirrors the PWA OPFS pattern.
            DictionaryData.shared.writeCache(file: info.file, bytes: data)

            // Notify before fulfilling the continuation: if the app is in
            // background, the notification is the only signal. If we're
            // foregrounded, the notification is suppressed inside
            // postCompletionNotification.
            self.postCompletionNotification(file: info.file, kind: kind)

            // Hand bytes back to any awaiter. The DictionaryData side
            // takes care of loading them into the WASM persist arena.
            self.fulfilContinuation(file: info.file, data: data)

            if self.activeFile == info.file {
                self.activeFile = nil
                self.activeFileProgress = 0
            }
        }
    }

    nonisolated func urlSession(
        _: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        // Success path resolves in `didFinishDownloadingTo`; this fires
        // on the failure path (network error, timeout) or as the tail of
        // a successful download (with `error == nil`, which we skip).
        guard let error else { return }
        let taskId = task.taskIdentifier
        Task { @MainActor [weak self] in
            guard let self else { return }
            guard let info = self.taskInfos.removeValue(forKey: taskId) else { return }
            self.persistTaskInfos()
            self.failContinuation(file: info.file, error: error)
            if self.activeFile == info.file {
                self.activeFile = nil
                self.activeFileProgress = 0
                self.lastError = error.localizedDescription
            }
        }
    }

    nonisolated func urlSessionDidFinishEvents(forBackgroundURLSession _: URLSession) {
        // Fired only on the relaunched-in-background path, after every
        // pending event has been delivered. We must call the handler iOS
        // gave us so it knows it's safe to re-suspend the process.
        Task { @MainActor in
            AppDelegate.backgroundCompletionHandler?()
            AppDelegate.backgroundCompletionHandler = nil
        }
    }

    private func fulfilContinuation(file: String, data: Data) {
        guard let cont = continuations.removeValue(forKey: file) else { return }
        cont.resume(returning: data)
    }

    private func failContinuation(file: String, error: Error) {
        guard let cont = continuations.removeValue(forKey: file) else { return }
        cont.resume(throwing: error)
    }
}
