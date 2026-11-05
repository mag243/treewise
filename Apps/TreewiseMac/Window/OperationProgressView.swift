import SwiftUI
import TreewiseCore
import TreewiseUI

/// A small panel with the progress of a transfer and buttons that pause,
/// resume and stop it (ADR 0026), shown only once it has run for a second, so
/// quick operations do not flash it (PLAN.md §5).
struct OperationProgressView: View {
    private static let delay = Duration.seconds(1)
    private static let width: CGFloat = 340
    private static let padding: CGFloat = 12

    let browser: BrowserState
    @State private var isShown = false

    var body: some View {
        Group {
            if isShown, let progress = browser.progress {
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(
                            ProgressText.text(
                                for: progress, isPaused: browser.isPaused,
                                locale: .autoupdatingCurrent)
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
                    Button("Stop", action: browser.cancelOperation)
                }
                .frame(width: Self.width)
                .padding(Self.padding)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Self.padding))
                .padding(Self.padding)
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
