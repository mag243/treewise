import SwiftUI
import TreewiseCore
import TreewiseModuleInterface
import TreewiseUI
import UniformTypeIdentifiers

/// The Add-ons tab of Settings (ADR 0070): every add-on the app has, with what it reads,
/// which files it is for and the fields it fills in; on or off for every folder, on in new
/// folders or not, and dragged into the order folders without their own take.
struct AddOnsSettingsTab: View {
    @Bindable var settings: BrowserSettings
    @State private var modules: [NameModuleDescription] = []

    private var catalog: [String] { modules.map(\.id) }

    private var ordered: [NameModuleDescription] {
        settings.addOns.ordered(catalog).compactMap { id in modules.first { $0.id == id } }
    }

    var body: some View {
        Form {
            Section {
                ForEach(ordered, id: \.id) { module in
                    AddOnRow(settings: settings, module: module, catalog: catalog)
                        .accessibilityActions {
                            Button("Move Up") { move(module.id, by: -1) }
                            Button("Move Down") { move(module.id, by: 1) }
                        }
                }
                .onMove { source, destination in
                    guard let from = source.first else { return }
                    let id = ordered[from].id
                    settings.addOns.move(
                        id, to: destination > from ? destination - 1 : destination, catalog: catalog
                    )
                }
            } header: {
                Text("Add-ons")
            } footer: {
                Text(
                    "An add-on that is off is offered in no folder. Drag to set the order for folders without their own."
                )
                .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .task { modules = (try? await NameReviewWindow.host.availableModules()) ?? [] }
    }

    private func move(_ id: String, by offset: Int) {
        guard let index = ordered.firstIndex(where: { $0.id == id }) else { return }
        settings.addOns.move(id, to: index + offset, catalog: catalog)
    }
}

/// One add-on.
private struct AddOnRow: View {
    @Bindable var settings: BrowserSettings
    let module: NameModuleDescription
    let catalog: [String]

    private var isOn: Bool { settings.addOns.isOn(module.id) }
    private var isLast: Bool { isOn && settings.addOns.available(catalog).count == 1 }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Toggle(
                    NameReviewText.name(ofModule: module.id),
                    isOn: Binding(
                        get: { isOn },
                        set: { settings.addOns.setOn(module.id, on: $0, catalog: catalog) })
                )
                .toggleStyle(.checkbox)
                .disabled(isLast)
                .help(isLast ? Text("At least one add-on stays on") : Text(""))
                Spacer()
                Text(module.isFree ? "Free" : "Paid").font(.caption).foregroundStyle(.secondary)
            }
            Group {
                Text(Self.reads(module))
                Text("For \(Self.files(module))")
                Text("Fields: \(module.fields.map { "{\($0.name)}" }.joined(separator: " "))")
            }
            .font(.caption).foregroundStyle(.secondary)
            .padding(.leading, 20)
            Toggle(
                "On in new folders",
                isOn: Binding(
                    get: {
                        settings.addOns.isOnInNewFolders(
                            module.id, defaultID: NameModuleDescription.defaultModuleID)
                    },
                    set: {
                        settings.addOns.setOnInNewFolders(
                            module.id, on: $0, catalog: catalog,
                            defaultID: NameModuleDescription.defaultModuleID)
                    })
            )
            .toggleStyle(.checkbox)
            .font(.caption)
            .padding(.leading, 20)
            .disabled(!isOn)
        }
        .opacity(isOn ? 1 : 0.6)
    }

    /// What the add-on reads of a file, in words (ADR 0061, ADR 0062).
    static func reads(_ module: NameModuleDescription) -> String {
        if module.neededContent.contains(.pageImages) {
            return String(localized: "Reads names and the pages of a file")
        }
        if !module.neededContent.isEmpty {
            return String(localized: "Reads names and the text of a file")
        }
        return String(localized: "Reads names only")
    }

    /// Which files the add-on is for, in words from its content types.
    static func files(_ module: NameModuleDescription) -> String {
        let types = module.contentTypes.compactMap { UTType($0) }
        if types.contains(where: { $0 == .item || $0 == .data }) {
            return String(localized: "all files")
        }
        return types.compactMap(\.localizedDescription).sorted().joined(separator: ", ")
    }
}
