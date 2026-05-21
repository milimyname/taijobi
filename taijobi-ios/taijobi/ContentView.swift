import SwiftUI

/// Two-tab shell — Lexikon for the user's saved words, Wörterbuch for live
/// lookup. Both share the App-Group SQLite; both surface the install prompt
/// for dictionaries (the dictionary tab inline, the lexicon implicitly via
/// "tap row to see full definition").
struct ContentView: View {
    var body: some View {
        TabView {
            LexiconView()
                .tabItem {
                    Label("Lexikon", systemImage: "book.closed")
                }
            DictionaryView()
                .tabItem {
                    Label("Wörterbuch", systemImage: "magnifyingglass")
                }
            ReadingView()
                .tabItem {
                    Label("Lesen", systemImage: "text.book.closed")
                }
            SettingsView()
                .tabItem {
                    Label("Einstellungen", systemImage: "gearshape")
                }
        }
    }
}
