import SwiftUI

/// Reading mode — paste a paragraph (Chinese / German / English), every
/// word becomes tappable, tap → popover with CEDICT or Wiktextract entry
/// + one-tap "save to lexicon". Mirrors taijobi-web/src/routes/(app)/read.
///
/// Tokenisation is the same greedy-longest-match for CJK (try 4→3→2 chars
/// against CEDICT, fall back to per-character) and word-boundary for
/// Latin scripts. Lookup is instant because the dictionaries live in the
/// same App-Group WASM bytes that LibTaijobi loaded at boot.
struct ReadingView: View {
	@State private var text = ""
	@State private var selected: TokenSelection?
	@State private var savedThisSession: Set<String> = []
	@State private var errorMessage: String?

	private let samples: [(label: String, text: String)] = [
		(
			"Chinesisch (HSK 3)",
			"今天天气很好，我们一起去公园散步。妹妹喜欢吃苹果，但是哥哥更喜欢香蕉。"
		),
		(
			"Deutsch",
			"Die Sprache ist nicht nur ein Werkzeug der Kommunikation, sondern auch ein Spiegel der Kultur. Wer eine neue Sprache lernt, gewinnt ein neues Fenster zur Welt."
		),
		(
			"Englisch",
			"Reading widely is the cheapest way to acquire vocabulary you can actually use. Pick a paragraph, tap unfamiliar words, save the ones worth keeping."
		),
	]

	var body: some View {
		NavigationStack {
			ScrollView {
				VStack(alignment: .leading, spacing: 16) {
					TextEditor(text: $text)
						.frame(minHeight: 120)
						.padding(8)
						.background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
						.overlay(alignment: .topLeading) {
							if text.isEmpty {
								Text("Hier Text einfügen — Chinesisch, Deutsch oder Englisch.")
									.foregroundStyle(.secondary)
									.padding(.horizontal, 14)
									.padding(.vertical, 16)
									.allowsHitTesting(false)
							}
						}

					sampleStrip

					if !text.isEmpty {
						renderedBlock
					} else {
						emptyState
					}

					if let errorMessage {
						Text(errorMessage)
							.font(.caption)
							.foregroundStyle(.red)
					}
				}
				.padding()
			}
			.navigationTitle("Lesen")
			.sheet(item: $selected) { selection in
				LookupSheet(
					token: selection.token,
					results: selection.results,
					alreadySaved: savedThisSession.contains(selection.token),
					onSave: { saveToken(selection.token) }
				)
				.presentationDetents([.medium, .large])
			}
		}
	}

	// MARK: - Subviews

	private var sampleStrip: some View {
		ScrollView(.horizontal, showsIndicators: false) {
			HStack(spacing: 8) {
				Text("Beispiel:")
					.font(.caption)
					.foregroundStyle(.secondary)
				ForEach(samples, id: \.label) { sample in
					Button(sample.label) {
						text = sample.text
						savedThisSession = []
						errorMessage = nil
					}
					.font(.caption.weight(.medium))
					.buttonStyle(.bordered)
					.controlSize(.small)
				}
				if !text.isEmpty {
					Button("Leeren") {
						text = ""
						savedThisSession = []
					}
					.font(.caption)
					.foregroundStyle(.secondary)
					.buttonStyle(.borderless)
				}
			}
		}
	}

	private var renderedBlock: some View {
		let tokens = Tokenizer.tokenize(text)
		return VStack(alignment: .leading, spacing: 8) {
			TokenFlow(tokens: tokens, savedThisSession: savedThisSession) { token in
				let results = LibTaijobi.shared.lookupWord(token)
				selected = TokenSelection(token: token, results: results)
			}
			Text(
				"Tippe ein Wort für Übersetzung + Speichern. Chinesisch nutzt CC-CEDICT (längste Übereinstimmung), Latein/Deutsch Wiktextract."
			)
			.font(.caption2)
			.foregroundStyle(.secondary)
		}
		.padding()
		.background(.background.secondary, in: RoundedRectangle(cornerRadius: 16))
	}

	private var emptyState: some View {
		VStack(spacing: 12) {
			Image(systemName: "book.closed")
				.font(.system(size: 32))
				.foregroundStyle(.tint)
				.padding(16)
				.background(.tint.opacity(0.1), in: Circle())
			Text("Füge oben Text ein oder wähle ein Beispiel.")
				.font(.subheadline)
				.foregroundStyle(.secondary)
		}
		.frame(maxWidth: .infinity)
		.padding(.vertical, 48)
	}

	// MARK: - Actions

	private func saveToken(_ token: String) {
		do {
			_ = try LibTaijobi.shared.addWord(token)
			savedThisSession.insert(token)
			errorMessage = nil
		} catch {
			errorMessage = "Speichern fehlgeschlagen: \(error)"
		}
	}
}

// MARK: - Token model + lookup sheet

private struct TokenSelection: Identifiable {
	let token: String
	let results: [DictResult]
	var id: String { token }
}

private struct LookupSheet: View {
	let token: String
	let results: [DictResult]
	let alreadySaved: Bool
	let onSave: () -> Void
	@Environment(\.dismiss) private var dismiss

	var body: some View {
		NavigationStack {
			ScrollView {
				VStack(alignment: .leading, spacing: 16) {
					Text(token)
						.font(.system(size: 32, weight: .bold))

					if results.isEmpty {
						Text("Kein Wörterbucheintrag — du kannst es trotzdem speichern.")
							.font(.subheadline.italic())
							.foregroundStyle(.secondary)
					} else {
						ForEach(results.prefix(5)) { result in
							WiktEntryView(result: result)
						}
						if results.count > 5 {
							Text("+\(results.count - 5) weitere Einträge")
								.font(.caption)
								.foregroundStyle(.secondary)
						}
					}

					Button {
						onSave()
						dismiss()
					} label: {
						Label(
							alreadySaved ? "Bereits gespeichert" : "Zum Lexikon hinzufügen",
							systemImage: alreadySaved ? "checkmark" : "plus"
						)
						.frame(maxWidth: .infinity)
					}
					.buttonStyle(.borderedProminent)
					.disabled(alreadySaved)
					.padding(.top, 8)
				}
				.padding()
			}
			.navigationTitle("Nachschlagen")
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button("Schließen") { dismiss() }
				}
			}
		}
	}
}

// MARK: - Tokeniser (port of taijobi-web/src/routes/(app)/read/+page.svelte)

enum Tokenizer {
	struct Token: Hashable {
		let text: String
		let tappable: Bool
	}

	static func tokenize(_ input: String) -> [Token] {
		let chars = Array(input)
		var tokens: [Token] = []
		var i = 0
		while i < chars.count {
			let ch = chars[i]
			if isCjk(ch) {
				// Greedy longest match — try 4, 3, 2; fall back to 1.
				var matched: String?
				let maxLen = min(4, chars.count - i)
				for len in stride(from: maxLen, through: 2, by: -1) {
					let candidate = String(chars[i ..< i + len])
					if !LibTaijobi.shared.lookupWord(candidate).isEmpty {
						matched = candidate
						break
					}
				}
				if let matched {
					tokens.append(Token(text: matched, tappable: true))
					i += matched.count
				} else {
					tokens.append(Token(text: String(ch), tappable: true))
					i += 1
				}
			} else if ch.isLetter {
				var j = i
				while j < chars.count, chars[j].isLetter || chars[j] == "'" || chars[j] == "’" || chars[j] == "-" {
					j += 1
				}
				let word = String(chars[i ..< j])
				tokens.append(Token(text: word, tappable: word.count >= 2))
				i = j
			} else {
				var j = i
				while j < chars.count, !isCjk(chars[j]), !chars[j].isLetter {
					j += 1
				}
				tokens.append(Token(text: String(chars[i ..< j]), tappable: false))
				i = j
			}
		}
		return tokens
	}

	private static func isCjk(_ ch: Character) -> Bool {
		guard let scalar = ch.unicodeScalars.first else { return false }
		let v = scalar.value
		return (0x4E00 ... 0x9FFF).contains(v)
			|| (0x3400 ... 0x4DBF).contains(v)
			|| (0x20000 ... 0x2A6DF).contains(v)
	}
}

// MARK: - Flow layout

/// Wrapping HStack via SwiftUI's Layout protocol. Each token gets its own
/// subview so tap targets stay tight to the glyph instead of grabbing
/// whole lines. Spaces are rendered as their own non-tappable subview so
/// wrapping breaks where the source text would break.
private struct TokenFlow: View {
	let tokens: [Tokenizer.Token]
	let savedThisSession: Set<String>
	let onTap: (String) -> Void

	var body: some View {
		FlowLayout(spacing: 0) {
			ForEach(Array(tokens.enumerated()), id: \.offset) { _, token in
				if token.tappable {
					Button {
						onTap(token.text)
					} label: {
						Text(token.text)
							.foregroundStyle(.primary)
							.padding(.horizontal, 2)
							.padding(.vertical, 1)
							.background(
								savedThisSession.contains(token.text)
									? Color.green.opacity(0.2)
									: Color.clear,
								in: RoundedRectangle(cornerRadius: 4)
							)
					}
					.buttonStyle(.plain)
				} else {
					Text(token.text)
						.foregroundStyle(.primary)
				}
			}
		}
		.font(.title3)
	}
}

private struct FlowLayout: Layout {
	let spacing: CGFloat

	init(spacing: CGFloat = 4) {
		self.spacing = spacing
	}

	func sizeThatFits(
		proposal: ProposedViewSize,
		subviews: Subviews,
		cache _: inout ()
	) -> CGSize {
		let containerWidth = proposal.width ?? .infinity
		let (size, _) = layout(subviews: subviews, in: containerWidth)
		return size
	}

	func placeSubviews(
		in bounds: CGRect,
		proposal: ProposedViewSize,
		subviews: Subviews,
		cache _: inout ()
	) {
		let containerWidth = proposal.width ?? bounds.width
		let (_, positions) = layout(subviews: subviews, in: containerWidth)
		for (index, position) in positions.enumerated() {
			subviews[index].place(
				at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
				anchor: .topLeading,
				proposal: ProposedViewSize(positions[index].size)
			)
		}
	}

	private struct Slot {
		var x: CGFloat
		var y: CGFloat
		var size: CGSize
	}

	private func layout(
		subviews: Subviews,
		in containerWidth: CGFloat
	) -> (CGSize, [Slot]) {
		var slots: [Slot] = []
		var cursorX: CGFloat = 0
		var cursorY: CGFloat = 0
		var lineHeight: CGFloat = 0
		var maxX: CGFloat = 0

		for subview in subviews {
			let size = subview.sizeThatFits(.unspecified)
			if cursorX + size.width > containerWidth, cursorX > 0 {
				cursorX = 0
				cursorY += lineHeight + spacing
				lineHeight = 0
			}
			slots.append(Slot(x: cursorX, y: cursorY, size: size))
			cursorX += size.width
			lineHeight = max(lineHeight, size.height)
			maxX = max(maxX, cursorX)
		}

		return (CGSize(width: maxX, height: cursorY + lineHeight), slots)
	}
}
