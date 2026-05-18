import SwiftUI

/// Dictionary lookup screen — unified search across CC-CEDICT (Chinese) and
/// Wiktionary EN/DE. Mirrors taijobi-web/src/routes/(app)/dictionary/+page.svelte:
/// a single search field that hits every loaded dictionary in parallel, plus
/// an install prompt up top while dictionaries are still missing.
struct DictionaryView: View {
    @ObservedObject private var dict = DictionaryData.shared

    @State private var query = ""
    @State private var cedictHits: [CedictResult] = []
    @State private var wiktHits: [DictResult] = []
    @State private var debounceTask: Task<Void, Never>?
    @State private var addedWords: Set<String> = []
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchField

                if !dict.zhLoaded || !dict.enLoaded || !dict.deLoaded {
                    installCard
                        .padding(.horizontal)
                        .padding(.top, 4)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                }

                results
            }
            .navigationTitle("Wörterbuch")
            .background(Color(.systemGroupedBackground))
        }
    }

    // MARK: - Search field

    private var searchField: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Suche…", text: $query)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .onChange(of: query) { _, newValue in
                    scheduleSearch(newValue)
                }
            if !query.isEmpty {
                Button {
                    query = ""
                    cedictHits = []
                    wiktHits = []
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(10)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        .padding()
    }

    // MARK: - Install card

    private var installCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "square.and.arrow.down")
                    .foregroundStyle(.tint)
                Text("Wörterbücher installieren")
                    .font(.subheadline.weight(.semibold))
                Spacer()
            }
            Text("Lade die Wörterbücher einmalig herunter — danach funktioniert die Suche offline.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                ForEach(DictionaryData.Kind.allCases) { kind in
                    installButton(for: kind)
                }
            }

            if dict.active != nil {
                ProgressView(value: dict.progress)
                    .tint(.accentColor)
            }
            if let err = dict.lastError {
                Text(err)
                    .font(.caption2)
                    .foregroundStyle(.red)
            }
        }
        .padding(12)
        .background(.tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }

    private func installButton(for kind: DictionaryData.Kind) -> some View {
        let loaded: Bool = switch kind {
        case .zh: dict.zhLoaded
        case .en: dict.enLoaded
        case .de: dict.deLoaded
        }
        let isActive = dict.active == kind

        return Button {
            Task { await dict.install(kind) }
        } label: {
            HStack(spacing: 4) {
                if loaded {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
                Text(kind.label)
                if !loaded {
                    Text("\(kind.approxSizeMB) MB")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                loaded ? Color.green.opacity(0.12) : Color.accentColor.opacity(0.12),
                in: Capsule()
            )
        }
        .disabled(loaded || dict.active != nil)
        .opacity(isActive ? 0.6 : 1)
    }

    // MARK: - Results

    @ViewBuilder
    private var results: some View {
        if query.trimmingCharacters(in: .whitespaces).isEmpty {
            ContentUnavailableView(
                "Suche starten",
                systemImage: "character.book.closed",
                description: Text(
                    "Tippe ein chinesisches Zeichen, ein Pinyin oder ein englisches/deutsches Wort."
                )
            )
        } else if cedictHits.isEmpty && wiktHits.isEmpty {
            ContentUnavailableView(
                "Keine Ergebnisse",
                systemImage: "magnifyingglass",
                description: Text("Probier eine andere Schreibweise oder Sprache.")
            )
        } else {
            List {
                if !cedictHits.isEmpty {
                    Section("CC-CEDICT") {
                        ForEach(cedictHits) { hit in
                            cedictRow(hit)
                        }
                    }
                }
                if !wiktHits.isEmpty {
                    Section("Wiktionary") {
                        ForEach(wiktHits) { hit in
                            wiktRow(hit)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
    }

    private func cedictRow(_ hit: CedictResult) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(hit.simplified)
                    .font(.title2.weight(.medium))
                if hit.traditional != hit.simplified {
                    Text(hit.traditional)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Text(hit.pinyin)
                    .font(.subheadline)
                    .foregroundStyle(.tint)
                Spacer()
                addButton(word: hit.simplified)
            }
            Text(hit.english)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(3)
        }
        .padding(.vertical, 2)
    }

    private func wiktRow(_ hit: DictResult) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(hit.word)
                    .font(.headline)
                Spacer()
                addButton(word: hit.word)
            }
            WiktEntryView(result: hit)
        }
        .padding(.vertical, 2)
    }

    private func addButton(word: String) -> some View {
        let added = addedWords.contains(word)
        return Button {
            do {
                _ = try LibTaijobi.shared.addWord(word)
                addedWords.insert(word)
            } catch {
                errorMessage = "\(error)"
            }
        } label: {
            Image(systemName: added ? "checkmark.circle.fill" : "plus.circle")
                .font(.title3)
                .foregroundStyle(added ? Color.green : Color.accentColor)
        }
        .buttonStyle(.plain)
        .disabled(added)
    }

    // MARK: - Search

    private func scheduleSearch(_ raw: String) {
        debounceTask?.cancel()
        let q = raw.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else {
            cedictHits = []
            wiktHits = []
            return
        }
        debounceTask = Task { @MainActor in
            // 180 ms debounce — long enough that fast typing doesn't trigger
            // a search per keystroke, short enough that the user sees results
            // before they finish reaching for the screen.
            try? await Task.sleep(nanoseconds: 180_000_000)
            if Task.isCancelled { return }
            performSearch(q)
        }
    }

    private func performSearch(_ q: String) {
        cedictHits = dict.zhLoaded ? LibTaijobi.shared.lookupCedict(q) : []
        wiktHits = (dict.enLoaded || dict.deLoaded) ? LibTaijobi.shared.lookupWord(q) : []
    }
}
