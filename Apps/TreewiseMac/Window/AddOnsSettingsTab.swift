import SwiftUI
import TreewiseCore
import TreewiseModuleInterface
import TreewiseUI
import UniformTypeIdentifiers

/// The Add-ons tab of Settings (ADR 0070): every add-on the app has, with what it reads,
/// which files it is for and the fields it fills in; on or off for every folder, on in new
/// folders or not, and dragged into the order folders without their own take. A paid one
/// shows its licence, with Buy…; one Enter Licence Key… serves them all (ADR 0071).
struct AddOnsSettingsTab: View {
    @Bindable var settings: BrowserSettings
    /// The app's licences.
    let licences: LicenceKeeper
    @State private var modules: [NameModuleDescription] = []
    @State private var states: [String: ModuleLicenceState] = [:]
    @State private var entersKey = false

    private var catalog: [String] { modules.map(\.id) }
    /// The add-ons on that may work: one of them stays on.
    private var working: [String] {
        settings.addOns.available(catalog).filter { states[$0] != .unlicensed }
    }

    private var ordered: [NameModuleDescription] {
        settings.addOns.ordered(catalog).compactMap { id in modules.first { $0.id == id } }
    }

    var body: some View {
        Form {
            Section {
                ForEach(ordered, id: \.id) { module in
                    AddOnRow(
                        settings: settings, module: module, catalog: catalog,
                        defaultID: NameModuleDescription.defaultID(among: modules),
                        licence: states[module.id], isLastWorking: working == [module.id]
                    )
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
            if !states.isEmpty {
                Section {
                    Button("Enter Licence Key…") { entersKey = true }
                }
            }
        }
        .formStyle(.grouped)
        .task { await load() }
        .licenceKeyEntry(
            isPresented: $entersKey, keeper: licences, host: NameReviewWindow.host,
            onUnlocked: { Task { await load() } })
    }

    /// The add-ons, with each paid one's licence. None that another replaces is shown while
    /// that one may work, and the choices made for it go to that one (ADR 0067); one without
    /// a licence replaces nothing (ADR 0071).
    private func load() async {
        let host = NameReviewWindow.host
        let all = (try? await host.availableModules()) ?? []
        let context = licences.context()
        var found: [String: ModuleLicenceState] = [:]
        for module in all where !module.isFree {
            found[module.id] = try? await host.licenceState(moduleID: module.id, licence: context)
        }
        let mayWork = { (module: NameModuleDescription) in found[module.id] != .unlicensed }
        let offered = NameModuleDescription.offered(all.filter(mayWork))
        for module in all where !mayWork(module) {
            for replaced in module.replaces {
                settings.addOns.handOver(from: module.id, to: replaced)
            }
        }
        for module in offered {
            for replaced in module.replaces {
                settings.addOns.handOver(from: replaced, to: module.id)
            }
        }
        states = found
        modules = offered + all.filter { !mayWork($0) }
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
    /// The add-on that plays the default module's part (ADR 0067).
    let defaultID: String
    /// Its licence, for a paid add-on (ADR 0071).
    let licence: ModuleLicenceState?
    /// Whether it is the last add-on on that may work, which stays on.
    let isLastWorking: Bool

    /// Without a licence it is off and cannot be turned on; what was chosen is kept.
    private var isLocked: Bool { licence == .unlicensed }
    private var isOn: Bool { settings.addOns.isOn(module.id) && !isLocked }
    private var isLast: Bool { isOn && isLastWorking }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Toggle(
                    NameReviewText.name(of: module),
                    isOn: Binding(
                        get: { isOn },
                        set: { settings.addOns.setOn(module.id, on: $0, catalog: catalog) })
                )
                .toggleStyle(.checkbox)
                .disabled(isLast || isLocked)
                .help(isLast ? Text("At least one add-on stays on") : Text(verbatim: ""))
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
            if let licence {
                HStack(spacing: 6) {
                    Label(
                        LicenceText.state(licence),
                        systemImage: isLocked ? "lock.fill" : "key.fill"
                    )
                    .foregroundStyle(isLocked ? Color.orange : .secondary)
                    if !Self.isLicensed(licence), module.purchaseURL != nil {
                        Button("Buy…") { LicenceText.buy(module) }.buttonStyle(.link)
                    }
                }
                .font(.caption)
                .padding(.leading, 20)
            }
            Toggle(
                "On in new folders",
                isOn: Binding(
                    get: {
                        settings.addOns.isOnInNewFolders(
                            module.id, defaultID: defaultID)
                    },
                    set: {
                        settings.addOns.setOnInNewFolders(
                            module.id, on: $0, catalog: catalog,
                            defaultID: defaultID)
                    })
            )
            .toggleStyle(.checkbox)
            .font(.caption)
            .padding(.leading, 20)
            .disabled(!isOn)
        }
        .opacity(isOn ? 1 : 0.6)
    }

    private static func isLicensed(_ state: ModuleLicenceState) -> Bool {
        if case .licensed = state { true } else { false }
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
