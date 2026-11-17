import SwiftUI
import TreewiseCore
import TreewiseUI

/// A file in the name overview (ADR 0129): a tick to approve, its name with the proposal
/// beneath, which can be typed over, the arrows through the other proposals, and a swipe to
/// skip it, as the Mac's row offers.
struct NameReviewRow: View {
    let model: NameReviewModel
    let entry: NameProposalSession.Entry

    var body: some View {
        HStack(spacing: 12) {
            approval
            Image(systemName: ItemSymbol.name(for: item))
                .foregroundStyle(entry.kind.isContainer ? Color.accentColor : .secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.originalName)
                    .lineLimit(1)
                    .truncationMode(.middle)
                proposal
                if let problem {
                    Text(problem).font(.caption).foregroundStyle(.red)
                }
            }
            Spacer(minLength: 0)
            if (entry.position?.count ?? 0) > 1 { steps }
        }
        .swipeActions { skipActions }
    }

    /// The item, as the lists show its symbol.
    private var item: FileItem {
        FileItem(id: entry.id, name: entry.originalName, kind: entry.kind, volume: "")
    }

    @ViewBuilder private var approval: some View {
        if entry.restsFitting {
            Image(systemName: "checkmark")
                .foregroundStyle(.secondary)
                .accessibilityLabel(Text("Already fits"))
        } else {
            Button {
                if entry.state == .approved {
                    model.undecide(entry.id)
                } else {
                    _ = model.approve(entry.id)
                }
            } label: {
                Image(systemName: entry.state == .approved ? "checkmark.circle.fill" : "circle")
                    .imageScale(.large)
            }
            .buttonStyle(.borderless)
            .disabled(entry.isOutOfScope || entry.state == .skipped)
            .accessibilityLabel(Text("Approve"))
            // The UI tests find it by it.
            .accessibilityIdentifier("approve-\(entry.originalName)")
            .accessibilityAddTraits(entry.state == .approved ? .isSelected : [])
        }
    }

    /// The proposal, which can be typed over, its parts coloured as the pattern's fields
    /// and a gap or a date to check as on the Mac (ADR 0130).
    private var proposal: some View {
        let name = entry.currentName ?? ""
        return NameTextField(
            text: Binding(get: { name }, set: { model.edit(entry.id, to: $0) }),
            marks: NameMark.fields(model.fieldMarks(of: entry.id))
                + NameMark.look(in: name, dateFromFile: entry.currentDateSource != nil),
            style: .init(
                font: .preferredFont(forTextStyle: .callout),
                textColor: model.conflicts[entry.id] == nil ? .label : .systemRed,
                placeholder: emptyText, isStruckThrough: entry.state == .skipped,
                // The UI tests find it by it.
                identifier: "proposal-\(entry.originalName)"),
            isEnabled: !entry.isOutOfScope && entry.state != .skipped,
            onSubmit: { model.finishEditing(entry.id) })
    }

    /// What the proposal says while there is none.
    private var emptyText: String {
        if entry.isOutOfScope { return String(localized: "Not for these add-ons. Stays as it is.") }
        return model.readingCount > 0
            ? String(localized: "Reading the file…")
            : String(localized: "No proposal. Type a name.")
    }

    /// Why the name shown cannot be used, as the Mac's row says it.
    private var problem: String? {
        if let conflict = model.conflicts[entry.id] { return NameReviewText.text(for: conflict) }
        guard entry.currentName != nil, let problem = entry.problem else { return nil }
        return NameReviewText.text(for: problem)
    }

    private var steps: some View {
        HStack(spacing: 4) {
            Button {
                model.step(entry.id, by: .previous)
            } label: {
                Image(systemName: "chevron.left")
            }
            .accessibilityLabel(Text("Previous"))
            Button {
                model.step(entry.id, by: .next)
            } label: {
                Image(systemName: "chevron.right")
            }
            .accessibilityLabel(Text("Next"))
        }
        .buttonStyle(.borderless)
    }

    @ViewBuilder private var skipActions: some View {
        if model.isAlwaysSkipped(entry.id) {
            Button("Back in List") { Task { await model.stopAlwaysSkipping(entry.id) } }
        } else if entry.state == .skipped {
            Button("Undo Skip") { model.undecide(entry.id) }
        } else if !entry.restsFitting, !entry.isOutOfScope {
            Button("Skip") { model.skip(entry.id) }
            Button("Always Skip") { Task { await model.alwaysSkip(entry.id) } }
                .tint(.orange)
        }
    }
}
