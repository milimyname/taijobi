import SwiftUI

/// Two-tab shell — Wörter for combined lexicon + dictionary lookup,
/// Einstellungen for sync key management. Both share the App-Group SQLite.
struct ContentView: View {
    var body: some View {
        TabView {
            LexiconView()
                .tabItem {
                    Label("Wörter", systemImage: "book.closed")
                }
            SettingsView()
                .tabItem {
                    Label("Einstellungen", systemImage: "gearshape")
                }
        }
    }
}
