import AppKit
import SwiftUI
import TreewiseCore
import TreewiseUI

/// The list of files: two lines per row, the original above the new name, in one size and
/// starting at one place, so differences stand out. The list scrolls by itself.
struct NameReviewListView: View {
    let model: NameReviewModel
    @Binding var showsHidden: Bool
    /// The row whose name a double click asked to edit, until its field has the focus.
    @State private var editing: FileItem.ID?

    var body: some View {
        ScrollViewReader { proxy in
            List(selection: selection) {
                ForEach(model.rows) { row(for: $0) }
                if !model.hiddenRows.isEmpty {
                    Button {
                        showsHidden.toggle()
                    } label: {
                        Label(
                            hiddenLine, systemImage: showsHidden ? "chevron.down" : "chevron.right"
                        )
                        .font(.caption).foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    if showsHidden { ForEach(model.hiddenRows) { row(for: $0) } }
                }
            }
            .listStyle(.inset)
            // A double click on a row edits its name at once.
            .contextMenu(
                forSelectionType: FileItem.ID.self, menu: { _ in },
                primaryAction: { ids in
                    guard let id = ids.first else { return }
                    model.selectedID = id
                    editing = id
                }
            )
            .onChange(of: model.selectedID) { _, id in
                if let id {
                    proxy.scrollTo(id)
                    // A Quick Look panel that is shown follows the selection, as in the list.
                    QuickLookSource.shared.follow([URL(fileURLWithPath: id.rawValue)])
                }
            }
            .onKeyPress(action: handle)
        }
    }

    private var selection: Binding<FileItem.ID?> {
        Binding(get: { model.selectedID }, set: { model.selectedID = $0 })
    }

    private func row(for entry: NameProposalSession.Entry) -> some View {
        NameReviewRow(
            entry: entry, model: model, isSelected: entry.id == model.selectedID,
            startsEditing: editing == entry.id, onStartedEditing: { editing = nil }
        )
        .tag(entry.id)
        .id(entry.id)
    }

    private var hiddenLine: String {
        let skipped = model.hiddenRows.filter { model.isAlwaysSkipped($0.id) }.count
        let fitting = model.hiddenRows.count - skipped
        return skipped == 0
            ? String(localized: "\(fitting) files already fit")
            : String(localized: "\(fitting) files already fit, \(skipped) always skipped")
    }

    private func handle(_ press: KeyPress) -> KeyPress.Result {
        if press.key == .upArrow || press.key == .downArrow { return passToNameField(press) }
        // SwiftUI asks the list before the name's field, so the field has to be ruled out here.
        let isTyping = NSApp.keyWindow?.firstResponder is NSText
        if !isTyping, press.modifiers.isEmpty, let id = model.selectedID {
            // As in the file list: Return edits the name, Space shows the file.
            if press.key == .return, let entry = model.session?.entry(id),
                !entry.isOutOfScope, !entry.restsFitting
            {
                editing = id
                return .handled
            }
            if press.key == .space {
                QuickLookSource.shared.toggle([URL(fileURLWithPath: id.rawValue)])
                return .handled
            }
        }
        let key: NameReviewKey
        switch press.key {
        case .leftArrow: key = .previous
        case .rightArrow: key = .next
        case KeyEquivalent("a"): key = .approve
        case KeyEquivalent("s"): key = .skip
        default: return .ignored
        }
        return model.handle(key, isTyping: isTyping) ? .handled : .ignored
    }

    /// Hands ↑ and ↓ to the name being edited, which steps through its options (ADR 0064).
    /// SwiftUI asks the list first, and the list would take them to move its selection.
    private func passToNameField(_ press: KeyPress) -> KeyPress.Result {
        guard let editor = NSApp.keyWindow?.firstResponder as? NSTextView else { return .ignored }
        editor.doCommand(
            by: press.key == .upArrow
                ? #selector(NSResponder.moveUp(_:)) : #selector(NSResponder.moveDown(_:)))
        return .handled
    }
}

/// One file in the list.
struct NameReviewRow: View {
    private static let lineHeight: CGFloat = 18
    private static let iconSize: CGFloat = 28

    let entry: NameProposalSession.Entry
    let model: NameReviewModel
    let isSelected: Bool
    /// Whether the name's field is to take the focus, after a double click on the row.
    let startsEditing: Bool
    let onStartedEditing: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            approval.frame(width: 18)
            Image(nsImage: NSWorkspace.shared.icon(forFile: entry.id.rawValue))
                .resizable().frame(width: Self.iconSize, height: Self.iconSize)
            VStack(alignment: .leading, spacing: 0) {
                Text(entry.originalName).foregroundStyle(.secondary)
                newName
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            side
        }
        .opacity(entry.state == .skipped ? 0.5 : 1)
    }

    @ViewBuilder
    private var approval: some View {
        if entry.restsFitting {
            Image(systemName: "checkmark").foregroundStyle(.green).help("Already fits")
        } else if !entry.isOutOfScope {
            Toggle(
                "Approve",
                isOn: Binding(
                    get: { entry.state == .approved },
                    set: { approved in
                        if approved {
                            model.approve(entry.id)
                        } else {
                            model.undecide(entry.id)
                        }
                    })
            )
            .labelsHidden()
            .toggleStyle(.checkbox)
        }
    }

    @ViewBuilder
    private var newName: some View {
        if isSelected, !entry.isOutOfScope, !entry.restsFitting {
            NameReviewField(
                text: entry.currentName ?? "", placeholder: emptyText,
                onChange: { model.edit(entry.id, to: $0) },
                onFinish: { model.finishEditing(entry.id) },
                marks: model.fieldMarks(of: entry.id).map {
                    ColoredRange(
                        range: NSRange($0.range, in: entry.currentName ?? ""),
                        colorIndex: $0.colorIndex)
                },
                lookMarks: lookMarks(in: entry.currentName ?? ""),
                startsEditing: startsEditing, onStartedEditing: onStartedEditing,
                onStep: (entry.position?.count ?? 0) > 1
                    ? { direction in
                        model.step(entry.id, by: direction)
                        return model.session?.entry(entry.id)?.currentName
                    } : nil
            )
            .frame(height: Self.lineHeight)
        } else if let name = entry.restsFitting ? entry.originalName : entry.currentName {
            Text(marked(name)).foregroundStyle(
                model.conflicts[entry.id] == nil ? .primary : Color.red)
        } else {
            Text(emptyText).italic().foregroundStyle(.tertiary)
        }
    }

    private var emptyText: String {
        if entry.isOutOfScope { return String(localized: "Not for these add-ons. Stays as it is.") }
        return model.readingCount > 0
            ? String(localized: "Reading the file…")
            : String(localized: "No proposal. Type a name.")
    }

    /// The gap, or the date of a name whose date needs a look, for the field being edited.
    private func lookMarks(in name: String) -> [ColoredRange] {
        let text = name as NSString
        let gap = text.range(of: NameTemplate.gap)
        if gap.location != NSNotFound { return [ColoredRange(range: gap, tint: .gap)] }
        guard needsLook else { return [] }
        let date = text.range(of: dateText(in: name))
        return date.location == NSNotFound || date.length == text.length
            ? [] : [ColoredRange(range: date, tint: .dateToCheck)]
    }

    /// Colours a gap, and the date of a name whose date needs a look.
    private func marked(_ name: String) -> AttributedString {
        var text = AttributedString(name)
        if let range = text.range(of: NameTemplate.gap) {
            text[range].backgroundColor = .accentColor.opacity(0.25)
        } else if needsLook, let range = text.range(of: dateText(in: name)) {
            text[range].backgroundColor = .orange.opacity(0.25)
        }
        return text
    }

    private var needsLook: Bool { entry.currentDateSource != nil }

    private func dateText(in name: String) -> String {
        name.range(of: "[0-9]{2,4}[.-][0-9]{2}[.-][0-9]{2,4}|[0-9]{8}", options: .regularExpression)
            .map { String(name[$0]) } ?? name
    }

    private var hasProblem: Bool {
        model.conflicts[entry.id] != nil || !entry.personalData.isEmpty
            || (entry.currentName != nil && entry.problem != nil && entry.problem != .unchanged)
    }

    private var side: some View {
        HStack(spacing: 4) {
            if isSelected, entry.proposals.count + (entry.edit == nil ? 0 : 1) > 1 {
                Button {
                    model.step(entry.id, by: .previous)
                } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.plain)
            }
            Text(position).font(.caption).monospacedDigit().foregroundStyle(.secondary)
            if isSelected, entry.proposals.count + (entry.edit == nil ? 0 : 1) > 1 {
                Button {
                    model.step(entry.id, by: .next)
                } label: {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.plain)
            }
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                .opacity(hasProblem ? 1 : 0)
            if isSelected { skipMenu }
        }
    }

    private var position: String {
        entry.position.map { "\($0.index + 1)/\($0.count)" } ?? ""
    }

    @ViewBuilder
    private var skipMenu: some View {
        if model.isAlwaysSkipped(entry.id) {
            Button("Back in List") { Task { await model.stopAlwaysSkipping(entry.id) } }
                .buttonStyle(.link).font(.caption)
        } else if entry.state == .skipped {
            Button("Undo Skip") { model.undecide(entry.id) }.buttonStyle(.link).font(.caption)
        } else if !entry.restsFitting, !entry.isOutOfScope {
            Menu("Skip") {
                Button("Skip") { model.skip(entry.id) }
                Button("Always Skip") { Task { await model.alwaysSkip(entry.id) } }
            }
            .menuStyle(.borderlessButton).fixedSize().font(.caption)
        }
    }
}
