import SwiftUI
import TreewiseCore
import TreewiseUI

/// The progress of a transfer at the bottom of the folder, with Pause,
/// Resume and Stop (ADR 0026, ADR 0047). It shows only once the transfer has
/// run for a second, as on the Mac, so quick operations do not flash it, and
/// stays away while the transfer waits for the answer to a conflict, when
/// nothing is moving yet.
struct ProgressBar: View {
    private static let delay = Duration.seconds(1)
    private static let spacing: CGFloat = 6

    let browser: BrowserState
    /// Whether the conflict sheet asks about a name.
    let isAsking: Bool
    @Environment(\.locale) private var locale
    @State private var isShown = false

    var body: some View {
        Group {
            if isShown, !isAsking, let progress = browser.progress {
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: Self.spacing) {
                        Text(
                            ProgressText.text(
                                for: progress, isPaused: browser.isPaused, locale: locale)
                        )
                        .font(.callout)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        ProgressView(value: progress.fraction)
                    }
                    if browser.isPaused {
                        Button("Resume", action: browser.resumeOperation)
                    } else {
                        Button("Pause", action: browser.pauseOperation)
                    }
                    Button("Stop", role: .destructive, action: browser.cancelOperation)
                }
                .buttonStyle(.bordered)
                .padding()
                .background(.bar)
            }
        }
        .task(id: browser.progress == nil) {
            isShown = false
            guard browser.progress != nil else { return }
            try? await Task.sleep(for: Self.delay)
            isShown = browser.progress != nil
        }
    }
}
