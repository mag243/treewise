import AppKit
import TreewiseCore
import TreewiseModuleInterface
import TreewiseUI

/// What an add-on's block in the overview's header asks of the header.
@MainActor
struct AddOnBlockActions {
    /// Starts or stops editing the add-on's pattern.
    var edit: (String?) -> Void
    /// Asks a name to save the add-on's pattern under (ADR 0068).
    var save: (String) -> Void
    /// Offers Enter Licence Key… (ADR 0071).
    var enterKey: () -> Void
}

/// One add-on in the overview's header: its line, the editor of its pattern while that is
/// edited, and a newer version of its saved pattern. The editor stays while the line is
/// shown again, so the pattern being typed keeps its editor.
@MainActor
final class AddOnBlock: NSStackView {
    static let dragType = NSPasteboard.PasteboardType("me.m-domain.treewise.review-add-on")
    private static let spacing: CGFloat = 10
    private static let toggleWidth: CGFloat = 130
    private static let dimmed: CGFloat = 0.5

    let moduleID: String
    private let model: NameReviewModel
    private let actions: AddOnBlockActions
    private let line = NSStackView()
    private var editor: AddOnPatternEditor?
    private var newer: NSView?

    init(moduleID: String, model: NameReviewModel, actions: AddOnBlockActions) {
        self.moduleID = moduleID
        self.model = model
        self.actions = actions
        super.init(frame: .zero)
        orientation = .vertical
        alignment = .leading
        spacing = 0
        line.spacing = Self.spacing
        addArrangedSubview(line)
        registerForDraggedTypes([Self.dragType])
        setAccessibilityCustomActions([
            NSAccessibilityCustomAction(name: String(localized: "Move Up")) { [weak self] in
                self?.move(by: -1)
                return true
            },
            NSAccessibilityCustomAction(name: String(localized: "Move Down")) { [weak self] in
                self?.move(by: 1)
                return true
            },
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    /// Shows the add-on as the review has it now; `isEditing` whether its pattern is edited.
    func show(_ module: NameReviewModule, isEditing: Bool) {
        line.setViews(lineViews(module, isEditing: isEditing), in: .leading)
        showEditor(module, isEditing: isEditing)
        newer?.removeFromSuperview()
        newer = nil
        if module.isOn, let pattern = model.newerSavedPattern(for: module.id) {
            let view = NewerPatternVersion.view(model: model, pattern: pattern, moduleID: module.id)
            addArrangedSubview(view)
            newer = view
        }
    }

    private func showEditor(_ module: NameReviewModule, isEditing: Bool) {
        guard isEditing else {
            editor?.removeFromSuperview()
            editor = nil
            return
        }
        if let editor {
            editor.show(module)
            return
        }
        let editor = AddOnPatternEditor(module: module, model: model) { [actions] in
            actions.edit(nil)
        }
        insertArrangedSubview(editor, at: 1)
        self.editor = editor
    }

    /// Gives the pattern being edited `text`, as a saved or found pattern was taken.
    func showDraft(_ text: String) {
        editor?.showDraft(text)
    }

    // MARK: - The line

    private func lineViews(_ module: NameReviewModule, isEditing: Bool) -> [NSView] {
        let model = model
        let id = module.id
        var views: [NSView] = []
        if model.modules.count > 1 { views.append(AddOnGrip(moduleID: id)) }
        let toggle = ClosureCheckbox(title: NameReviewText.name(of: module)) { isOn in
            Task { await model.setModule(id, on: isOn) }
        }
        toggle.state = module.isOn ? .on : .off
        // One without a licence cannot be turned on (ADR 0071).
        toggle.isEnabled =
            !(module.licence == .unlicensed
            || (module.isOn && model.modules.filter(\.isOn).count == 1))
        toggle.widthAnchor.constraint(greaterThanOrEqualToConstant: Self.toggleWidth).isActive =
            true
        views.append(toggle)
        let pattern = NSTextField(
            labelWithAttributedString: PatternText.coloured(module.templateText))
        pattern.lineBreakMode = .byTruncatingTail
        pattern.alphaValue = module.isOn ? 1 : Self.dimmed
        pattern.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        views.append(pattern)
        let origin = NSTextField(labelWithString: NameReviewText.origin(of: module))
        origin.font = .preferredFont(forTextStyle: .caption1)
        origin.textColor = module.origin == .user ? .controlAccentColor : .secondaryLabelColor
        views.append(origin)
        views += licenceViews(module)
        views += links(module, isEditing: isEditing)
        return views
    }

    /// The licence of a paid add-on: quiet in its trial, a lock and the way to a licence
    /// when it needs one, nothing when licensed (ADR 0071).
    private func licenceViews(_ module: NameReviewModule) -> [NSView] {
        switch module.licence {
        case .trial(let days):
            let text = NSTextField(labelWithString: LicenceText.state(.trial(daysLeft: days)))
            text.font = .preferredFont(forTextStyle: .caption1)
            text.textColor = .secondaryLabelColor
            return [text]
        case .unlicensed:
            let lock = NSImageView(
                image: NSImage(systemSymbolName: "lock.fill", accessibilityDescription: nil)
                    ?? NSImage())
            lock.contentTintColor = .systemOrange
            let text = NSTextField(labelWithString: LicenceText.state(.unlicensed))
            text.font = .preferredFont(forTextStyle: .caption1)
            text.textColor = .systemOrange
            var views: [NSView] = [lock, text]
            if module.description.purchaseURL != nil {
                let description = module.description
                views.append(LinkButton(String(localized: "Buy…")) { LicenceText.buy(description) })
            }
            views.append(
                LinkButton(String(localized: "Enter Licence Key…")) { [actions] in
                    actions.enterKey()
                })
            return views
        case .licensed, nil:
            return []
        }
    }

    private func links(_ module: NameReviewModule, isEditing: Bool) -> [NSView] {
        let model = model
        let id = module.id
        var views: [NSView] = []
        if module.isOn, module.origin == .notRecognized, !isEditing {
            views.append(
                LinkButton(String(localized: "Use Your Default: \(model.defaultPattern)")) {
                    Task { await model.useDefaultPattern(id) }
                })
            views.append(savedPatterns(module, title: String(localized: "Choose a Saved Pattern")))
        } else if module.isOn {
            views.append(savedPatterns(module, title: nil))
        }
        if module.isOn, !isEditing {
            views.append(LinkButton(String(localized: "Change")) { [actions] in actions.edit(id) })
        }
        return views
    }

    /// The menu of saved patterns for the add-on, as an icon or under a title.
    private func savedPatterns(_ module: NameReviewModule, title: String?) -> NSView {
        let model = model
        let id = module.id
        let menu = SavedPatternsMenu(title: title)
        menu.choices = { model.savedPatternChoices(for: id) }
        menu.found = {
            let now = model.modules.first { $0.id == id }
            return (now?.candidates ?? [], now?.templateText ?? "")
        }
        menu.use = { [weak self] pattern in
            Task {
                await model.useSavedPattern(pattern, for: id)
                self?.showDraft(model.modules.first { $0.id == id }?.templateText ?? "")
            }
        }
        menu.useFound = { [weak self] text in
            Task {
                await model.useFoundPattern(text, for: id)
                self?.showDraft(text)
            }
        }
        menu.toUpdate = { model.savedPatternToUpdate(for: id)?.name }
        menu.update = { Task { await model.updateSavedPattern(for: id) } }
        menu.save = { [actions] in actions.save(id) }
        menu.edit = { SettingsWindow.show() }
        return menu
    }

    private func move(by offset: Int) {
        guard let place = model.modules.firstIndex(where: { $0.id == moduleID }) else { return }
        let model = model
        let id = moduleID
        Task { await model.moveModule(id, to: place + offset) }
    }

    // MARK: - Dropping another add-on here

    override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        draggedID(sender).map { $0 == moduleID ? [] : .move } ?? []
    }

    override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        guard let id = draggedID(sender), id != moduleID,
            let place = model.modules.firstIndex(where: { $0.id == moduleID })
        else { return false }
        let model = model
        Task { await model.moveModule(id, to: place) }
        return true
    }

    private func draggedID(_ info: any NSDraggingInfo) -> String? {
        info.draggingPasteboard.string(forType: Self.dragType)
    }
}

/// The grip that moves an add-on: the first one gives the first name (ADR 0065).
@MainActor
private final class AddOnGrip: NSImageView, NSDraggingSource {
    private let moduleID: String

    init(moduleID: String) {
        self.moduleID = moduleID
        super.init(frame: .zero)
        image = NSImage(systemSymbolName: "line.3.horizontal", accessibilityDescription: nil)
        contentTintColor = .tertiaryLabelColor
        toolTip = String(localized: "Drag to change the order of the add-ons")
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override func mouseDown(with event: NSEvent) {
        let item = NSPasteboardItem()
        item.setString(moduleID, forType: AddOnBlock.dragType)
        let dragged = NSDraggingItem(pasteboardWriter: item)
        dragged.setDraggingFrame(bounds, contents: image)
        beginDraggingSession(with: [dragged], event: event, source: self)
    }

    func draggingSession(
        _ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext
    ) -> NSDragOperation {
        context == .withinApplication ? .move : []
    }
}
