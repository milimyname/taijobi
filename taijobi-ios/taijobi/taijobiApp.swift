import SwiftUI

@main
struct TaijobiApp: App {
    @State private var initError: String?

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
    }

    init() {
        do {
            try LibTaijobi.shared.initialize()
            // Reload whatever's already cached in the App Group container
            // from a prior install, so lookup works immediately after launch
            // without re-downloading.
            DictionaryData.shared.loadCachedOnBoot()
        } catch {
            _initError = State(initialValue: "\(error)")
        }
    }
}
