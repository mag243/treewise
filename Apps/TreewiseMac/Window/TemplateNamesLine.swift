import AppKit
import TreewiseCore

/// The line below a template's tree in Settings' Templates tab that says which name settings
/// the selected folder gives the folders made from it, with Remove (ADR 0101). It shows only
/// while the add-on may work and the folder has name settings.
@MainActor
final class TemplateNamesLine: NSObject {
    private let label = NSTextField(wrappingLabelWithString: "")
    private lazy var remove = NSButton(
        title: String(localized: "Remove"), target: self, action: #selector(removeNames))
    /// Called when Remove is clicked.
    var onRemove: () -> Void = {}

    /// The line's view.
    private(set) lazy var view: NSView = {
        label.textColor = .secondaryLabelColor
        label.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        label.setAccessibilityIdentifier("templateNameSettings")
        remove.controlSize = .small
        remove.setAccessibilityIdentifier("removeTemplateNameSettings")
        let stack = NSStackView(views: [label, remove])
        stack.alignment = .firstBaseline
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        stack.isHidden = true
        return stack
    }()

    /// Shows the name settings of the folder selected, or hides the line.
    func show(_ names: FolderNameSettings?) {
        guard let names, FolderTemplatesService.addOnMayWork else {
            view.isHidden = true
            return
        }
        label.stringValue = Self.text(for: names, addOnNames: FolderTemplatesService.addOnNames)
        view.isHidden = false
    }

    /// `Names: Advanced Folder Pattern “{year} Invoice {seq}”`: each add-on that is on, in
    /// its order, with its pattern when it has one of its own.
    static func text(for names: FolderNameSettings, addOnNames: [String: String]) -> String {
        let addOns = names.enabledModules.map { id in
            let name = addOnNames[id] ?? id
            guard let pattern = names.patterns[id] else { return name }
            return "\(name) “\(pattern)”"
        }
        return String(localized: "Names: \(addOns.formatted(.list(type: .and)))")
    }

    @objc private func removeNames() {
        onRemove()
    }
}
