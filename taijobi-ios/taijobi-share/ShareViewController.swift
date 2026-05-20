import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// iOS Share Extension entry point. Receives text from any host app
/// (Safari selection, Live Text from Photos, x.com share, …) and hosts a
/// tiny SwiftUI sheet that lets the user trim/edit before saving into the
/// App-Group SQLite via the existing LibTaijobi C ABI.
///
/// Memory budget: iOS share extensions get ~120 MB. LibTaijobi is ~3 MB
/// of static lib + ~5 MB of SQLite. We never load any dictionary in the
/// extension — enrichment happens later inside the main app on first
/// boot or when the user opens the lexicon. That keeps us well clear of
/// the cap and avoids touching the dict download path from the extension.
@objc(ShareViewController)
final class ShareViewController: UIViewController {
	override func viewDidLoad() {
		super.viewDidLoad()
		view.backgroundColor = .clear
		Task { await loadInput() }
	}

	@MainActor
	private func loadInput() async {
		let captured = await readSharedText()
		let host = UIHostingController(
			rootView: ShareView(
				initialText: captured ?? "",
				onCommit: { [weak self] words in self?.commit(words: words) },
				onCancel: { [weak self] in self?.cancel() }
			)
		)
		host.view.backgroundColor = .clear
		addChild(host)
		host.view.translatesAutoresizingMaskIntoConstraints = false
		view.addSubview(host.view)
		NSLayoutConstraint.activate([
			host.view.topAnchor.constraint(equalTo: view.topAnchor),
			host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
			host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
			host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
		])
		host.didMove(toParent: self)
	}

	/// Walks the extension input items and pulls the first text/URL we find.
	/// Live Text → Share gives `public.plain-text`. Safari "Share Selection"
	/// gives the same. Sharing a URL falls back to the URL's string form so
	/// the user at least sees what they captured and can edit.
	private func readSharedText() async -> String? {
		guard let items = extensionContext?.inputItems as? [NSExtensionItem] else { return nil }
		for item in items {
			for provider in item.attachments ?? [] {
				if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
					if let raw = try? await provider.loadItem(
						forTypeIdentifier: UTType.plainText.identifier
					) {
						if let s = raw as? String { return s }
						if let data = raw as? Data {
							return String(data: data, encoding: .utf8)
						}
					}
				}
				if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
					if let raw = try? await provider.loadItem(
						forTypeIdentifier: UTType.url.identifier
					), let url = raw as? URL {
						return url.absoluteString
					}
				}
				if provider.hasItemConformingToTypeIdentifier(UTType.text.identifier) {
					if let raw = try? await provider.loadItem(
						forTypeIdentifier: UTType.text.identifier
					), let s = raw as? String {
						return s
					}
				}
			}
		}
		return nil
	}

	private func commit(words: [String]) {
		Task.detached(priority: .userInitiated) {
			do {
				try LibTaijobi.shared.initialize()
				for word in words {
					_ = try LibTaijobi.shared.addWord(word)
				}
			} catch {
				NSLog("[taijobi-share] commit failed: \(error)")
			}
			await MainActor.run { [weak self] in self?.finish() }
		}
	}

	private func cancel() {
		finish()
	}

	private func finish() {
		extensionContext?.completeRequest(returningItems: nil)
	}
}
