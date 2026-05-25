import SwiftUI

@main
struct TaijobiApp: App {
    @State private var initError: String?
    @Environment(\.scenePhase) private var scenePhase
    // SwiftUI's App protocol has no hook for
    // `application(_:handleEventsForBackgroundURLSession:completionHandler:)`,
    // which the background URLSession needs in order to finish dict
    // downloads while the app is suspended/terminated. The adaptor wires
    // a classic UIApplicationDelegate so we can receive that callback.
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            if let error = initError {
                VStack(spacing: 12) {
                    Text("Initialisierung fehlgeschlagen")
                        .font(.headline)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            } else {
                ContentView()
            }
        }
        // Pull whenever the app comes back to active — mirrors the web's
        // setOnReconnect path. Mutations made while foreground push
        // automatically via SyncService.start()'s onMutate hook, so we
        // mainly need to catch up on remote changes here.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                SyncService.shared.onForeground()
            }
        }
    }

    init() {
        do {
            try LibTaijobi.shared.initialize()
            // Reload whatever's already cached in the App Group container
            // from a prior install, so lookup works immediately after launch
            // without re-downloading.
            DictionaryData.shared.loadCachedOnBoot()
            // Wire mutation-driven auto-sync + run an initial sync if a
            // key is already set in the keychain.
            SyncService.shared.start()
        } catch {
            _initError = State(initialValue: "\(error)")
        }
    }
}
