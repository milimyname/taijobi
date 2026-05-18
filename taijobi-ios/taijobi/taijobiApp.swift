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
        } catch {
            _initError = State(initialValue: "\(error)")
        }
    }
}
