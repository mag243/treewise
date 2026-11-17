import SwiftUI
import TreewiseUI

/// Says that a folder just opened is still being read, in place of the folder left
/// (ADR 0121). It shows only after `delay`, so a folder read quickly does not flash it.
struct ReadingPlaceholder: View {
    /// How long a reading runs before the placeholder shows.
    static let delay = Duration.milliseconds(500)

    /// The name of the folder being read.
    let name: String
    @State private var isShown = false

    var body: some View {
        Group {
            if isShown {
                ProgressView {
                    Text("Reading \(name)…")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
                // The UI tests find it by it.
                .accessibilityIdentifier("reading")
            }
        }
        .task(id: name) {
            isShown = false
            try? await Task.sleep(for: Self.delay)
            isShown = !Task.isCancelled
        }
    }
}
