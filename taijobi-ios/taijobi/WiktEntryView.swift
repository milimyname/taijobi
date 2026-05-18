import SwiftUI

/// Structured Wiktionary entry — mirrors the web's `WiktEntry.svelte`.
/// POS chips, optional etymology, numbered senses with tags + example
/// sentences, plus synonyms/antonyms/hypernyms per sense.
struct WiktEntryView: View {
    let result: DictResult

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(result.groups, id: \.self) { group in
                posGroup(group)
            }
        }
    }

    private func posGroup(_ group: DictPosGroup) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(posLabel(group.pos))
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.tint.opacity(0.15), in: Capsule())
                    .foregroundStyle(.tint)
                Spacer()
            }

            if !group.etymology.isEmpty {
                HStack(alignment: .top, spacing: 4) {
                    Text("Herkunft:")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(group.etymology)
                        .font(.caption.italic())
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(group.senses.enumerated()), id: \.offset) { idx, sense in
                    senseRow(idx + 1, sense)
                }
            }
        }
    }

    private func senseRow(_ number: Int, _ sense: DictSense) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 6) {
                Text("\(number).")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 18, alignment: .trailing)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        if !sense.tags.isEmpty {
                            ForEach(sense.tags, id: \.self) { tag in
                                Text(tag)
                                    .font(.caption2.italic())
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(
                                        Color(.tertiarySystemFill),
                                        in: RoundedRectangle(cornerRadius: 3)
                                    )
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Text(sense.gloss)
                            .font(.footnote)
                            .foregroundStyle(.primary)
                    }

                    if !sense.example.isEmpty {
                        Text(sense.example)
                            .font(.caption.italic())
                            .foregroundStyle(.secondary)
                            .padding(.leading, 6)
                            .overlay(alignment: .leading) {
                                Rectangle()
                                    .frame(width: 2)
                                    .foregroundStyle(.tint.opacity(0.3))
                            }
                    }

                    if !sense.synonyms.isEmpty {
                        relations(label: "Syn.", words: sense.synonyms, color: .accentColor)
                    }
                    if !sense.antonyms.isEmpty {
                        relations(label: "Ant.", words: sense.antonyms, color: .pink)
                    }
                    if !sense.hypernyms.isEmpty {
                        relations(label: "⊃", words: sense.hypernyms, color: .gray)
                    }
                }
            }
        }
    }

    private func relations(label: String, words: [String], color: Color) -> some View {
        (Text(label).font(.caption2.weight(.semibold)).foregroundColor(color)
            + Text(" ").font(.caption2)
            + Text(words.joined(separator: " · "))
                .font(.caption2)
                .foregroundColor(.secondary))
            .lineLimit(2)
    }

    private func posLabel(_ pos: String) -> String {
        switch pos {
        case "n": return "Substantiv"
        case "v": return "Verb"
        case "adj": return "Adjektiv"
        case "adv": return "Adverb"
        case "prep": return "Präposition"
        case "conj": return "Konjunktion"
        case "pron": return "Pronomen"
        case "det": return "Determinator"
        case "intj": return "Interjektion"
        case "num": return "Numerale"
        case "part": return "Partikel"
        case "pfx": return "Präfix"
        case "sfx": return "Suffix"
        case "phr": return "Phrase"
        case "prov": return "Sprichwort"
        case "name": return "Eigenname"
        case "abbr": return "Abkürzung"
        default: return pos
        }
    }
}
