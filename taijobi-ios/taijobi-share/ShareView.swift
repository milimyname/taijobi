import SwiftUI

/// Tiny one-shot UI for the share extension: edit the captured text, pick
/// whether to add it as one entry or split into per-word entries, hit save.
///
/// "Split" mode is on by default when the captured text looks like a single
/// line of plain words (e.g. Live-Text from a book page); off when it looks
/// like a sentence or a URL. Heuristic only — the toggle is right there for
/// the user to flip.
struct ShareView: View {
	@State private var text: String
	@State private var splitWords: Bool
	let onCommit: ([String]) -> Void
	let onCancel: () -> Void

	init(
		initialText: String,
		onCommit: @escaping ([String]) -> Void,
		onCancel: @escaping () -> Void
	) {
		_text = State(initialValue: initialText)
		// Auto-split if there are 2-10 whitespace-separated tokens and no
		// sentence-ending punctuation — typical of OCR'd word lists. URLs and
		// prose fall through to single-entry mode.
		let trimmed = initialText.trimmingCharacters(in: .whitespacesAndNewlines)
		let looksLikeUrl = trimmed.contains("://")
		let tokenCount = trimmed
			.split(whereSeparator: { $0.isWhitespace })
			.count
		let hasSentencePunct = trimmed.contains(where: { ".!?".contains($0) })
		_splitWords = State(
			initialValue: !looksLikeUrl && !hasSentencePunct && (2 ... 10).contains(tokenCount)
		)
		self.onCommit = onCommit
		self.onCancel = onCancel
	}

	var words: [String] {
		let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !trimmed.isEmpty else { return [] }
		if splitWords {
			return trimmed
				.split(whereSeparator: { $0.isWhitespace || $0.isPunctuation })
				.map { String($0) }
				.filter { !$0.isEmpty }
		}
		return [trimmed]
	}

	var body: some View {
		NavigationStack {
			Form {
				Section("Text") {
					TextEditor(text: $text)
						.frame(minHeight: 120)
						.autocorrectionDisabled()
						.textInputAutocapitalization(.never)
				}
				Section {
					Toggle("In W\u{00F6}rter aufteilen", isOn: $splitWords)
					if splitWords {
						LabeledContent("Anzahl") {
							Text("\(words.count)")
								.foregroundStyle(.secondary)
						}
					}
				} footer: {
					if splitWords {
						Text("Trennt an Leerzeichen und Satzzeichen.")
					} else {
						Text("Wird als einzelner Eintrag im Lexikon gespeichert.")
					}
				}
			}
			.navigationTitle("Zu Taijobi")
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button("Abbrechen", action: onCancel)
				}
				ToolbarItem(placement: .confirmationAction) {
					Button("Hinzuf\u{00FC}gen") { onCommit(words) }
						.disabled(words.isEmpty)
				}
			}
		}
	}
}
