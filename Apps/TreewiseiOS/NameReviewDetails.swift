import QuickLook
import SwiftUI
import TreewiseCore
import TreewiseUI

/// The panel about the file chosen in the name overview, as the Mac's beside its list: the
/// file in Quick Look, what needs a look, where the name comes from, and the names around it
/// in the folder. Beside the list in landscape, in a sheet from a row's ⓘ otherwise.
struct NameReviewDetails: View {
    let model: NameReviewModel

    /// The height of the file's preview.
    private static let previewHeight: CGFloat = 260
    /// How strongly a name to be is marked among those around it.
    private static let newOpacity = 0.2

    var body: some View {
        if let entry = model.selectedID.flatMap({ model.session?.entry($0) }) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    FilePreview(url: URL(fileURLWithPath: entry.id.rawValue))
                        .frame(height: Self.previewHeight)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    ForEach(messages(for: entry), id: \.self) { warning($0) }
                    if entry.isOutOfScope {
                        caption(String(localized: "Not for these add-ons. Stays as it is."))
                    }
                    ForEach(source(of: entry), id: \.self) { caption($0) }
                    if !model.neighbours.isEmpty { neighbours }
                }
                .padding()
            }
            .accessibilityIdentifier("nameDetails")
        } else {
            ContentUnavailableView(
                String(localized: "No file chosen"), systemImage: "doc.text.magnifyingglass")
        }
    }

    /// What needs a look: a name taken, a name that cannot be, personal data, and a date that
    /// came from the file rather than its name.
    private func messages(for entry: NameProposalSession.Entry) -> [String] {
        var texts: [String] = []
        if let conflict = model.conflicts[entry.id] {
            texts.append(NameReviewText.text(for: conflict))
        } else if let problem = entry.problem, let text = NameReviewText.text(for: problem) {
            texts.append(text)
        }
        texts += entry.personalData.map { NameReviewText.text(for: $0) }
        switch entry.currentDateSource {
        case .fileSystem: texts.append(String(localized: "Date of the file, check it"))
        case .insideFile where model.isPhoto(entry.id):
            texts.append(String(localized: "Date from the photo, check it"))
        case .insideFile: texts.append(String(localized: "Date from the PDF, check it"))
        case nil: break
        }
        return texts
    }

    /// Where the name comes from and which add-ons it fits.
    private func source(of entry: NameProposalSession.Entry) -> [String] {
        let fitting = NameReviewText.names(ofModules: entry.fittingModuleIDs, in: model)
        if entry.restsFitting { return [String(localized: "Already fits \(fitting)")] }
        var texts: [String] = []
        if let proposal = entry.currentProposal {
            let from = NameReviewText.names(ofModules: proposal.moduleIDs, in: model)
            texts.append(String(localized: "From: \(from)"))
        } else if entry.currentName != nil {
            texts.append(String(localized: "From: \(String(localized: "You"))"))
        }
        if !entry.fittingModuleIDs.isEmpty { texts.append(String(localized: "Fits \(fitting)")) }
        return texts
    }

    private var neighbours: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("In This Folder").font(.caption.bold())
            ForEach(Array(model.neighbours.enumerated()), id: \.offset) { _, neighbour in
                Text(neighbour.name)
                    .font(.caption)
                    .lineLimit(2)
                    .foregroundStyle(neighbour.isNew ? .primary : .secondary)
                    .padding(.horizontal, neighbour.isNew ? 3 : 0)
                    .background(
                        neighbour.isNew ? Color.accentColor.opacity(Self.newOpacity) : .clear,
                        in: RoundedRectangle(cornerRadius: 3))
            }
        }
    }

    private func warning(_ text: String) -> some View {
        Label(text, systemImage: "exclamationmark.triangle")
            .font(.caption)
            .foregroundStyle(.red)
    }

    private func caption(_ text: String) -> some View {
        Text(text).font(.caption).foregroundStyle(.secondary)
    }
}

/// A file shown by Quick Look inside the panel, rather than over the screen. Hidden from
/// accessibility: Quick Look's view runs apart from the app and reports a frame wider than
/// the panel, over the list, which a reader would land on; the panel's texts say what matters.
private struct FilePreview: View {
    let url: URL

    var body: some View {
        QuickLookController(url: url).accessibilityHidden(true)
    }
}

private struct QuickLookController: UIViewControllerRepresentable {
    let url: URL

    func makeCoordinator() -> Source { Source() }

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        context.coordinator.url = url
        controller.dataSource = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: QLPreviewController, context: Context) {
        guard context.coordinator.url != url else { return }
        context.coordinator.url = url
        controller.reloadData()
    }

    /// The one file the preview shows.
    final class Source: NSObject, QLPreviewControllerDataSource {
        var url: URL?

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            url == nil ? 0 : 1
        }

        func previewController(_ controller: QLPreviewController, previewItemAt index: Int)
            -> any QLPreviewItem
        {
            (url ?? URL(fileURLWithPath: "/")) as NSURL
        }
    }
}
