import SwiftUI
import TreewiseCore
import TreewiseFileSystem
import TreewiseUI

/// Settings' General tab (ADR 0143, ADR 0144): syncing settings through the cloud drives,
/// the drives taking part, and the changes another device replaced.
struct GeneralSettings: View {
    let settings: BrowserSettings
    @State private var isReviewing = false

    var body: some View {
        Form {
            Section {
                Toggle(
                    "Sync settings through cloud drives",
                    isOn: Binding(
                        get: { settings.syncsSettings },
                        set: { isOn in Task { await IPadSync.controller?.setSyncing(isOn) } })
                )
                // The UI tests find it by it.
                .accessibilityIdentifier("syncsSettings")
            } footer: {
                Text(
                    "Folder settings, saved patterns and templates are kept in a hidden .treewise folder in iCloud Drive, Dropbox and your other cloud drives, so your Macs and your other devices have them too."
                )
            }
            if settings.syncsSettings, !IPadSync.cloudLocations.isEmpty {
                drives
            }
            if let controller = IPadSync.controller, !controller.replaced.isEmpty {
                Section {
                    Button("Replaced by another device: \(controller.replaced.count)") {
                        isReviewing = true
                    }
                }
            }
        }
        .navigationTitle(Text("General"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isReviewing) {
            if let controller = IPadSync.controller {
                SyncReplacedList(controller: controller, settings: settings)
            }
        }
    }

    private var drives: some View {
        Section {
            ForEach(IPadSync.cloudLocations) { drive in
                if drive.isRoot {
                    Toggle(
                        drive.name,
                        isOn: Binding(
                            get: { !settings.syncLeavesOut.contains(drive.folder.path) },
                            set: { takesPart in
                                Task {
                                    await IPadSync.setTakesPart(
                                        takesPart, drive.folder, settings: settings)
                                }
                            }))
                } else {
                    VStack(alignment: .leading) {
                        Text(verbatim: drive.name)
                        Text("A folder inside a drive: add the drive itself to sync it.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } header: {
            Text("Cloud Drives")
        }
    }
}

/// The changes of this device's another device's replaced, with Restore (ADR 0144).
struct SyncReplacedList: View {
    let controller: SyncController
    let settings: BrowserSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(controller.replaced) { entry in
                    row(entry)
                }
                Section {
                } footer: {
                    Text("Kept for 30 days on this device.")
                }
            }
            .navigationTitle(Text("Replaced Changes"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Clear") {
                        Task { await controller.clearReplaced() }
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func row(_ entry: SyncConflictStore.Entry) -> some View {
        let text = SyncConflictText(entry, names: name(of:))
        return VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: "\(text.title) · \(text.part)").font(.headline)
            Text(
                verbatim: [
                    entry.byDevice,
                    entry.conflict.winner.changedAt.formatted(date: .abbreviated, time: .shortened),
                ].compactMap { $0 }.joined(separator: " · ")
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
            Text("Yours: \(text.yours)   Now: \(text.now)")
            Button("Restore") { Task { await controller.restore(entry) } }
                .buttonStyle(.borderless)
        }
    }

    private func name(of element: SyncElement) -> String? {
        switch element {
        case .pattern(let id): settings.savedPatterns.patterns.first { $0.id == id }?.name
        case .template(let id): NameServices.templateList.templates.first { $0.id == id }?.name
        default: nil
        }
    }
}
