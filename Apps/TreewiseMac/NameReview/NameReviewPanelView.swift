import SwiftUI
import TreewiseCore
import TreewiseUI

/// The panel beside the list, about the selected row: the file, what needs a look, where
/// the name comes from, and the names around it. It stays in view while the list scrolls.
struct NameReviewPanelView: View {
    private static let previewHeight: CGFloat = 200

    let model: NameReviewModel

    private var entry: NameProposalSession.Entry? {
        model.selectedID.flatMap { model.session?.entry($0) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                if let entry {
                    if !model.isClosing {
                        QuickLookPreview(item: entry.id).frame(height: Self.previewHeight)
                    }
                    messages(for: entry)
                    source(of: entry)
                    neighbours
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func messages(for entry: NameProposalSession.Entry) -> some View {
        if let conflict = model.conflicts[entry.id] {
            warning(NameReviewText.text(for: conflict))
        } else if let problem = entry.problem, let text = NameReviewText.text(for: problem) {
            warning(text)
        }
        if entry.isOutOfScope { Text("Not for these add-ons. Stays as it is.").font(.caption) }
        switch entry.currentDateSource {
        case .fileSystem:
            warning(String(localized: "Date of the file, check it"))
        case .insideFile where model.isPhoto(entry.id):
            warning(String(localized: "Date from the photo, check it"))
        case .insideFile:
            warning(String(localized: "Date from the PDF, check it"))
        case nil:
            EmptyView()
        }
    }

    private func warning(_ text: String) -> some View {
        Label(text, systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(.orange)
    }

    @ViewBuilder
    private func source(of entry: NameProposalSession.Entry) -> some View {
        if entry.restsFitting {
            caption(
                String(
                    localized:
                        "Already fits \(NameReviewText.names(ofModules: entry.fittingModuleIDs, in: model))"
                ))
        } else if let from = from(entry) {
            caption(String(localized: "From: \(from)"))
        }
        if !entry.restsFitting, !entry.fittingModuleIDs.isEmpty {
            caption(
                String(
                    localized:
                        "Fits \(NameReviewText.names(ofModules: entry.fittingModuleIDs, in: model))"
                ))
        }
    }

    private func from(_ entry: NameProposalSession.Entry) -> String? {
        guard let index = entry.position?.index else { return nil }
        guard index < entry.proposals.count else { return String(localized: "You") }
        return NameReviewText.names(ofModules: entry.proposals[index].moduleIDs, in: model)
    }

    private func caption(_ text: String) -> some View {
        Text(text).font(.caption).foregroundStyle(.secondary)
    }

    private var neighbours: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("In This Folder").font(.caption.bold())
            ForEach(model.neighbours, id: \.name) { neighbour in
                Text(neighbour.name)
                    .font(.caption)
                    .lineLimit(2)
                    .padding(.horizontal, 4)
                    .background(neighbour.isNew ? Color.accentColor.opacity(0.2) : .clear)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                    .foregroundStyle(neighbour.isNew ? .primary : .secondary)
            }
        }
    }
}
