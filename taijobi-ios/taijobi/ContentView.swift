import SwiftUI

/// Minimal first-launch surface: a text field that hits `hanzi_add_word`
/// and a list of every entry returned by `hanzi_get_lexicon`. Sync, drill,
/// and richer UI come later — this is the bare floor for verifying that
/// the XCFramework links and the C ABI returns sensible JSON.
struct ContentView: View {
    @State private var lexicon: [LexiconEntry] = []
    @State private var input = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    TextField("Wort hinzufügen…", text: $input)
                        .textFieldStyle(.roundedBorder)
                        .submitLabel(.done)
                        .onSubmit(commitAdd)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    Button("Hinzufügen", action: commitAdd)
                        .buttonStyle(.borderedProminent)
                        .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding()

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                }

                List {
                    ForEach(lexicon) { entry in
                        LexiconRow(entry: entry)
                    }
                    .onDelete(perform: deleteRows)
                }
                .listStyle(.plain)
            }
            .navigationTitle("Lexikon")
            .onAppear(perform: refresh)
        }
    }

    private func commitAdd() {
        let word = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !word.isEmpty else { return }
        do {
            if try LibTaijobi.shared.addWord(word) != nil {
                input = ""
                errorMessage = nil
                refresh()
            } else {
                errorMessage = LibTaijobi.shared.lastError() ?? "Hinzufügen fehlgeschlagen"
            }
        } catch {
            errorMessage = "\(error)"
        }
    }

    private func refresh() {
        do {
            lexicon = try LibTaijobi.shared.getLexicon()
        } catch {
            errorMessage = "\(error)"
        }
    }

    private func deleteRows(at offsets: IndexSet) {
        for index in offsets {
            let entry = lexicon[index]
            _ = try? LibTaijobi.shared.removeWord(id: entry.id)
        }
        refresh()
    }
}

private struct LexiconRow: View {
    let entry: LexiconEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(entry.word)
                    .font(.headline)
                Text(entry.language.uppercased())
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.tint.opacity(0.15), in: Capsule())
                if let pinyin = entry.pinyin, !pinyin.isEmpty {
                    Text(pinyin)
                        .font(.subheadline)
                        .foregroundStyle(.tint)
                }
            }
            if let translation = entry.translation, !translation.isEmpty {
                Text(translation)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}
