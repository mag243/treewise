import SwiftUI
import TreewiseUI

/// Says that a folder just opened is still being read, in place of the folder left
/// (ADR 0121); `BrowserState.isReadingSlowly(_:)` says when, so a folder read quickly does
/// not flash it.
struct ReadingPlaceholder: View {
    /// The name of the folder being read.
    let name: String

    var body: some View {
        ProgressView {
            Text("Reading \(name)…")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        // The UI tests find it by it.
        .accessibilityIdentifier("reading")
    }
}
