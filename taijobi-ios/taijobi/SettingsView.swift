import SwiftUI

/// Settings screen — sync key management for now, room to grow.
/// Mirrors taijobi-web/src/routes/(app)/settings/+page.svelte's sync block:
/// generate key, paste key, copy key, manual sync, disconnect.
struct SettingsView: View {
    @StateObject private var sync = SyncService.shared

    @State private var pasteKey = ""
    @State private var showCopiedToast = false

    var body: some View {
        NavigationStack {
            Form {
                syncSection
            }
            .navigationTitle("Einstellungen")
        }
    }

    // MARK: - Sync section

    @ViewBuilder
    private var syncSection: some View {
        Section {
            if sync.hasKey {
                connectedRows
            } else {
                disconnectedRows
            }

            if sync.syncing {
                HStack {
                    ProgressView()
                        .controlSize(.small)
                    Text("Synchronisiere…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if let err = sync.lastError {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        } header: {
            Text("Sync")
        } footer: {
            Text(
                "Dein Sync-Schlüssel verschlüsselt deine Wörter lokal, bevor sie an den Server gesendet werden. Bewahre ihn sicher auf — ohne den Schlüssel kann niemand (auch nicht taijobi) auf deine Daten zugreifen."
            )
            .font(.caption)
        }
    }

    @ViewBuilder
    private var connectedRows: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text("Verbunden")
                .font(.subheadline.weight(.medium))
            Spacer()
            if sync.lastSyncMs > 0 {
                Text(lastSyncLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }

        Button {
            Task { await sync.sync() }
        } label: {
            Label("Jetzt synchronisieren", systemImage: "arrow.triangle.2.circlepath")
        }
        .disabled(sync.syncing)

        Button {
            if let key = sync.syncKey {
                UIPasteboard.general.string = key
                showCopiedToast = true
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                    showCopiedToast = false
                }
            }
        } label: {
            HStack {
                Label(
                    showCopiedToast ? "Kopiert!" : "Schlüssel kopieren",
                    systemImage: showCopiedToast ? "checkmark" : "doc.on.doc")
                Spacer()
                if let key = sync.syncKey {
                    Text(maskedKey(key))
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
            }
        }

        Button(role: .destructive) {
            sync.clearSyncKey()
        } label: {
            Label("Sync trennen", systemImage: "xmark.circle")
        }
    }

    @ViewBuilder
    private var disconnectedRows: some View {
        TextField("Sync-Schlüssel einfügen", text: $pasteKey)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .font(.caption.monospaced())

        Button {
            sync.setSyncKey(pasteKey)
            pasteKey = ""
        } label: {
            Label("Schlüssel verwenden", systemImage: "key.fill")
        }
        .disabled(pasteKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

        Button {
            let key = SyncService.generateKey()
            sync.setSyncKey(key)
            UIPasteboard.general.string = key
            showCopiedToast = true
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                showCopiedToast = false
            }
        } label: {
            Label("Neuen Schlüssel generieren", systemImage: "sparkles")
        }
    }

    // MARK: - Helpers

    private var lastSyncLabel: String {
        let date = Date(timeIntervalSince1970: TimeInterval(sync.lastSyncMs) / 1000)
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func maskedKey(_ key: String) -> String {
        // Show first 4 + last 4 so the user can sanity-check against another
        // device without exposing the whole thing on screen.
        guard key.count > 8 else { return key }
        return "\(key.prefix(4))…\(key.suffix(4))"
    }
}
