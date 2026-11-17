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

    private var proposal: some View {
        TextField(
            emptyText,
            text: Binding(
                get: { entry.currentName ?? "" },
                set: { model.edit(entry.id, to: $0) })
        )
        .onSubmit { model.finishEditing(entry.id) }
        // The UI tests find it by it.
        .accessibilityIdentifier("proposal-\(entry.originalName)")
        .font(.callout)
        .foregroundStyle(model.conflicts[entry.id] == nil ? Color.primary : .red)
        .disabled(entry.isOutOfScope || entry.state == .skipped)
        .strikethrough(entry.state == .skipped)
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
