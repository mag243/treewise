import SwiftUI
import TreewiseCore
import TreewiseUI

/// Below an add-on in the overview's add-ons header: a newer version of the saved pattern
/// this folder uses, in the colours of its fields, with Use It and Keep Mine (ADR 0068).
struct NewerPatternVersion: View {
    private static let indent: CGFloat = 24

    let model: NameReviewModel
    let pattern: SavedPattern
    let moduleID: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.triangle.2.circlepath").foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text("“\(pattern.name)” has a newer version:").font(.caption)
            Text(NameReviewAddOnsView.colored(pattern.text)).font(.caption.monospaced())
                .lineLimit(1)
            Button("Use It") { Task { await model.useNewerSavedPattern(for: moduleID) } }
                .buttonStyle(.link).font(.caption)
            Button("Keep Mine") { Task { await model.keepPatternInsteadOfNewer(for: moduleID) } }
                .buttonStyle(.link).font(.caption)
        }
        .padding(.leading, Self.indent)
    }
}
