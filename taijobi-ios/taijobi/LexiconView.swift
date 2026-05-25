import SwiftUI

/// Combined Lexikon + Wörterbuch screen. Mirrors taijobi-web's merged
/// `/lexicon` page:
///   * one input does triple duty: filter lexicon · search dictionary · add
///     a new word on Enter when no exact match exists
///   * dictionary install card at the top while any dict is missing
///   * lexicon list (tap to expand into full Wiktionary entry)
///   * dictionary results inline below the lexicon when the query has
///     CEDICT / Wiktionary hits the user hasn't saved yet
struct LexiconView: View {
    @ObservedObject private var dict = DictionaryData.shared
    /// Observed so the list re-fetches automatically when a WS broadcast
    /// or HTTP pull lands new rows. Without this, real-time sync writes
    /// into SQLite invisibly and the user has to leave + return to the
    /// tab to see them.
    @ObservedObject private var sync = SyncService.shared

    @State private var lexicon: [LexiconEntry] = []
    @State private var query = ""
    @State private var errorMessage: String?
    @State private var expandedId: String?
    @State private var expandedHit: DictResult?

    @State private var cedictHits: [CedictResult] = []
    @State private var wiktHits: [DictResult] = []
    @State private var debounceTask: Task<Void, Never>?
    @State private var addedWords: Set<String> = []

    private var anyDictMissing: Bool {
        !dict.zhLoaded || !dict.enLoaded || !dict.deLoaded
    }

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var lowerQuery: String {
        trimmedQuery.lowercased()
    }

    private var filteredLexicon: [LexiconEntry] {
        guard !lowerQuery.isEmpty else { return lexicon }
        return lexicon.filter { entry in
            entry.word.lowercased().contains(lowerQuery)
                || (entry.translation ?? "").lowercased().contains(lowerQuery)
                || (entry.pinyin ?? "").lowercased().contains(lowerQuery)
        }
    }

    private var exactMatch: Bool {
        guard !lowerQuery.isEmpty else { return false }
        return lexicon.contains { $0.word.lowercased() == lowerQuery }
    }

    private var savedWords: Set<String> {
        Set(lexicon.map { $0.word })
    }

    private var visibleCedict: [CedictResult] {
        let visible = Set(filteredLexicon.map { $0.word })
        return cedictHits.filter { !visible.contains($0.simplified) }
    }

    private var visibleWikt: [DictResult] {
        let visible = Set(filteredLexicon.map { $0.word })
        return wiktHits.filter { !visible.contains($0.word) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchAndAddRow
                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                }
                content
            }
            .navigationTitle("Wörter")
            .onAppear(perform: refresh)
            .onChange(of: sync.dataVersion) { _, _ in refresh() }
        }
    }

    // MARK: - Top bar

    private var searchAndAddRow: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Suchen oder hinzufügen…", text: $query)
                    .textFieldStyle(.plain)
                    .submitLabel(.done)
                    .onSubmit { if !exactMatch { commitAdd() } }
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
            .background(
                Color(.secondarySystemBackground),
                in: RoundedRectangle(cornerRadius: 12)
            )
            Button(action: commitAdd) {
                Image(systemName: "plus")
                    .font(.title3.weight(.semibold))
                    .frame(width: 44, height: 44)
                    .background(.tint, in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(.white)
            }
            .disabled(trimmedQuery.isEmpty || exactMatch)
        }
        .padding()
    }

    // MARK: - Main content split

    @ViewBuilder
    private var content: some View {
        List {
            if anyDictMissing {
                Section {
                    installCard
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
            }

            if !filteredLexicon.isEmpty {
                Section(filteredLexicon.count == 1 ? "Lexikon" : "Lexikon (\(filteredLexicon.count))") {
                    ForEach(filteredLexicon) { entry in
                        LexiconRow(
                            entry: entry,
                            expanded: expandedId == entry.id,
                            expandedHit: expandedId == entry.id ? expandedHit : nil,
                            onTap: { toggleExpand(entry) }
                        )
                    }
                    .onDelete(perform: deleteRows)
                }
            } else if lexicon.isEmpty && trimmedQuery.isEmpty {
                Section {
                    ContentUnavailableView(
                        "Noch keine Wörter",
                        systemImage: "tray",
                        description: Text("Tippe oben ein Wort ein — Enter speichert es.")
                    )
                }
                .listRowBackground(Color.clear)
            }

            if !visibleCedict.isEmpty {
                Section("CC-CEDICT") {
                    ForEach(visibleCedict) { hit in
                        cedictRow(hit)
                    }
                }
            }

            if !visibleWikt.isEmpty {
                Section("Wörterbuch") {
                    ForEach(visibleWikt) { hit in
                        wiktRow(hit)
                    }
                }
            }

            if !trimmedQuery.isEmpty
                && filteredLexicon.isEmpty
                && visibleCedict.isEmpty
                && visibleWikt.isEmpty {
                Section {
                    ContentUnavailableView(
                        "Keine Treffer",
                        systemImage: "magnifyingglass",
                        description: Text(
                            "Drücke Enter, um «\(trimmedQuery)» trotzdem ins Lexikon zu speichern."
                        )
                    )
                }
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Dictionary install card (collapsed version of old DictionaryView)

    private var installCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "square.and.arrow.down")
                    .foregroundStyle(.tint)
                Text("Wörterbücher installieren")
                    .font(.subheadline.weight(.semibold))
                Spacer()
            }
            Text("Einmalig laden — danach funktioniert die Suche offline.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                ForEach(DictionaryData.Kind.allCases) { kind in
                    installButton(for: kind)
                }
            }

            if let active = dict.active {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("\(active.label) wird geladen…")
                            .font(.caption.weight(.medium))
                        Spacer()
                        Text("\(Int((dict.progress * 100).rounded()))%")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    ProgressView(value: dict.progress, total: 1.0)
                        .progressViewStyle(.linear)
                        .tint(.accentColor)
                        .animation(.linear(duration: 0.15), value: dict.progress)
                    // iOS suspends URLSession.default downloads in background.
                    // Until we migrate to URLSessionConfiguration.background +
                    // a local notification on completion, surface a hint.
                    if active.approxSizeMB >= 30 {
                        Text("Lass die App offen, bis der Download fertig ist — iOS pausiert ihn sonst im Hintergrund.")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                            .padding(.top, 2)
                    }
                }
            }
            if let err = dict.lastError {
                Text(err)
                    .font(.caption2)
                    .foregroundStyle(.red)
            }
        }
        .padding(12)
        .background(.tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
        .padding(.top, 4)
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

    // MARK: - Rows

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
                speakerButton(word: hit.simplified, language: "zh")
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
                speakerButton(word: hit.word, language: "auto")
                addButton(word: hit.word)
            }
            WiktEntryView(result: hit)
        }
        .padding(.vertical, 2)
    }

    private func speakerButton(word: String, language: String) -> some View {
        Button {
            Speak.say(word, language: language)
        } label: {
            Image(systemName: "speaker.wave.2")
                .font(.subheadline)
                .foregroundStyle(.tint)
                .padding(6)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func addButton(word: String) -> some View {
        let added = savedWords.contains(word) || addedWords.contains(word)
        return Button {
            do {
                _ = try LibTaijobi.shared.addWord(word)
                addedWords.insert(word)
                refresh()
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

    // MARK: - Actions

    private func commitAdd() {
        let word = trimmedQuery
        guard !word.isEmpty, !exactMatch else { return }
        do {
            if try LibTaijobi.shared.addWord(word) != nil {
                query = ""
                errorMessage = nil
                cedictHits = []
                wiktHits = []
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
        let target = filteredLexicon
        for index in offsets {
            let entry = target[index]
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

    // MARK: - Dictionary search (debounced)

    private func scheduleSearch(_ raw: String) {
        debounceTask?.cancel()
        let q = raw.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else {
            cedictHits = []
            wiktHits = []
            return
        }
        let zhLoaded = dict.zhLoaded
        let dictsLoaded = dict.enLoaded || dict.deLoaded
        debounceTask = Task.detached(priority: .userInitiated) {
            // 180 ms debounce — long enough that fast typing doesn't trigger
            // a search per keystroke, short enough that the user sees results
            // before they finish reaching for the screen.
            try? await Task.sleep(nanoseconds: 180_000_000)
            if Task.isCancelled { return }
            // Run the WASM lookups off the main thread — they hold the
            // libtaijobi NSRecursiveLock and decode JSON; 5–50 ms for rich
            // Wiktionary hits, blocking the input field otherwise.
            let cedict = zhLoaded ? LibTaijobi.shared.lookupCedict(q) : []
            if Task.isCancelled { return }
            let wikt = dictsLoaded ? LibTaijobi.shared.lookupWord(q) : []
            if Task.isCancelled { return }
            await MainActor.run {
                self.cedictHits = cedict
                self.wiktHits = wikt
            }
        }
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
                    Button {
                        Speak.say(entry.word, language: entry.language)
                    } label: {
                        Image(systemName: "speaker.wave.2")
                            .font(.subheadline)
                            .foregroundStyle(.tint)
                            .padding(6)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
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
