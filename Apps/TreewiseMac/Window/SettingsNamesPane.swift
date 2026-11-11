import AppKit
import TreewiseCore
import TreewiseUI

/// Settings' Names pane: the saved patterns (ADR 0068), names with personal data
/// (ADR 0060) and clearing what Treewise keeps for each folder it suggested names
/// in, after asking (ADR 0072). Changes apply at once.
@MainActor
final class SettingsNamesPane: NSViewController {
    private static let choices: [PersonalDataInNames] = [.leaveOutOfApproveAll, .onlyWarn]
    private static let noteWidth: CGFloat = 340
    private static let groupSpacing: CGFloat = 20

    private let settings: BrowserSettings
    private lazy var patterns = SavedPatternsSection(settings: settings)
    private lazy var personalData = SettingsForm.popUp(
        [String(localized: "Leave out of Approve All"), String(localized: "Only warn")],
        accessibilityLabel: "Names with personal data"
    ) { [settings] in settings.personalDataInNames = Self.choices[$0] }

    init(settings: BrowserSettings) {
        self.settings = settings
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override func loadView() {
        let form = SettingsForm()
        form.row("Names with personal data:", personalData)
        form.note(
            "A proposed name with an e-mail address, phone number, bank account or payment card number is marked. A name you type is not.",
            width: Self.noteWidth)
        form.group()
        let clear = SettingsForm.button("Clear Folder Settings…") { [weak self] in
            self?.askToClearFolderSettings()
        }
        form.row("Folder settings:", clear)
        form.note(
            "For each folder you suggest names in, Treewise keeps which add-ons are on and their patterns. Those of a folder not seen for 30 days go by themselves.",
            width: Self.noteWidth)
        let stack = NSStackView(views: [patterns.makeView(), form.grid])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = Self.groupSpacing
        stack.translatesAutoresizingMaskIntoConstraints = false
        let size = SettingsWindow.paneSize
        let view = NSView(frame: NSRect(origin: .zero, size: size))
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            view.widthAnchor.constraint(equalToConstant: size.width),
            view.heightAnchor.constraint(equalToConstant: size.height),
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: SettingsForm.margin),
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])
        self.view = view
        Observing.follow(self) { $0.update() }
    }

    private func update() {
        personalData.selectItem(
            at: Self.choices.firstIndex(of: settings.personalDataInNames) ?? 0)
    }

    /// Clears every folder's settings once the user confirms; saved patterns stay.
    private func askToClearFolderSettings() {
        guard let window = view.window else { return }
        let alert = NSAlert()
        alert.messageText = String(localized: "Clear the settings of every folder?")
        alert.informativeText = String(
            localized:
                "Each folder starts again with the add-ons that are on in new folders, and its pattern is recognized again. Saved patterns stay."
        )
        let clear = alert.addButton(withTitle: String(localized: "Clear Folder Settings"))
        clear.hasDestructiveAction = true
        alert.addButton(withTitle: String(localized: "Cancel"))
        alert.beginSheetModal(for: window) { response in
            guard response == .alertFirstButtonReturn else { return }
            Task { await NameReviewWindow.store.clearAll() }
        }
    }
}
