import SwiftUI

/// Lexicon screen — quick-add input + scrollable list. Tapping a row
/// expands it to show the full Wiktionary entry (when a dict is loaded),
/// matching taijobi-web/src/routes/(app)/lexicon/+page.svelte.
struct LexiconView: View {
    @State private var lexicon: [LexiconEntry] = []
    @State private var input = ""
    @State private var errorMessage: String?
    @State private var expandedId: String?
    @State private var expandedHit: DictResult?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                addRow
                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                }
                if lexicon.isEmpty {
                    ContentUnavailableView(
                        "Lexikon ist leer",
                        systemImage: "tray",
                        description: Text("Tippe ein Wort oben ein, um zu starten.")
                    )
                } else {
                    list
                }
            }
            .navigationTitle("Lexikon")
            .onAppear(perform: refresh)
        }
    }

    // MARK: - Add row

    private var addRow: some View {
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
    }

    // MARK: - List

    private var list: some View {
        List {
            ForEach(lexicon) { entry in
                LexiconRow(
                    entry: entry,
                    expanded: expandedId == entry.id,
                    expandedHit: expandedId == entry.id ? expandedHit : nil,
                    onTap: { toggleExpand(entry) }
                )
            }
            .onDelete(perform: deleteRows)
        }
        .listStyle(.plain)
    }

    // MARK: - Actions

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
            if expandedId == entry.id {
                expandedId = nil
                expandedHit = nil
            }
        }
        refresh()
    }

    private func toggleExpand(_ entry: LexiconEntry) {
        if expandedId == entry.id {
            expandedId = nil
            expandedHit = nil
            return
        }
        let needle = entry.word.lowercased()
        let hits = LibTaijobi.shared.lookupWord(entry.word)
        expandedHit = hits.first { $0.word.lowercased() == needle }
        expandedId = entry.id
    }
}

private struct LexiconRow: View {
    let entry: LexiconEntry
    let expanded: Bool
    let expandedHit: DictResult?
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button(action: onTap) {
                HStack(alignment: .firstTextBaseline) {
                    Text(entry.word)
                        .font(.headline)
                    Text(entry.language.uppercased())
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.tint.opacity(0.15), in: Capsule())
                    if let pinyin = entry.pinyin, !pinyin.isEmpty {
                        Text(pinyin)
                            .font(.subheadline)
                            .foregroundStyle(.tint)
                    }
                    Spacer()
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            if let translation = entry.translation, !translation.isEmpty {
                Text(translation)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(expanded ? nil : 2)
            }

            if expanded {
                if let hit = expandedHit {
                    Divider()
                    WiktEntryView(result: hit)
                } else {
                    Text("Kein Wörterbuch-Eintrag für «\(entry.word)» gefunden.")
                        .font(.caption.italic())
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}
