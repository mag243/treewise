import SwiftUI
import TreewiseCore
import TreewiseFileSystem
import TreewiseUI

/// Settings' General tab (ADR 0143, ADR 0144): syncing settings through the cloud drives,
/// the drives taking part, and the changes another device replaced.
struct GeneralSettings: View {
    let settings: BrowserSettings
    @State private var isReviewing = false
    /// The drive the user asked to start syncing in from here, while it asks to go on.
    @State private var starting: IPadSync.Drive?

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
                    "Folder settings, saved patterns and templates are kept in a hidden .treewise.settings folder in iCloud Drive, Dropbox and your other cloud drives, so your Macs and your other devices have them too."
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
        .alert(
            "Start Syncing from This iPad?",
            isPresented: Binding(get: { starting != nil }, set: { if !$0 { starting = nil } }),
            presenting: starting
        ) { drive in
            Button("Cancel", role: .cancel) {}
            Button("Make Folder") {
                Task { await IPadSync.startHere(drive.folder, settings: settings) }
            }
        } message: { _ in
            Text(
                "On an iPad, a cloud drive's app may not keep a hidden folder, so Treewise makes a folder named Treewise.Settings you can see in the drive. A Mac that syncs this drive later uses it too."
            )
        }
        .sheet(isPresented: $isReviewing) {
            if let controller = IPadSync.controller {
                SyncReplacedList(controller: controller, settings: settings)
            }
        }
    }

    private var drives: some View {
        Section {
            ForEach(IPadSync.cloudLocations) { drive in
                if drive.isRoot, let problem = IPadSync.problem(of: drive.folder) {
                    waiting(drive, problem: problem)
                } else if drive.isRoot {
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

    /// A drive this device does not sync in: why, and how to start.
    private func waiting(_ drive: IPadSync.Drive, problem: SyncFolder.Problem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(verbatim: drive.name)
            switch problem {
            case .notStarted:
                Text("Starts once Treewise on a Mac syncs this drive.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button("Start Syncing from This iPad") { starting = drive }
                    .buttonStyle(.borderless)
            case .renamed:
                Text("The drive renamed Treewise's folder, so this device does not sync in it.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
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
