import AppKit
import TreewiseCore
import TreewiseUI

/// A small panel with the progress of a transfer and buttons that pause,
/// resume and stop it (ADR 0026), shown only once it has run for a second, so
/// quick operations do not flash it (PLAN.md §5).
@MainActor
final class OperationProgressView: NSVisualEffectView {
    private static let delay = Duration.seconds(1)
    private static let width: CGFloat = 340
    private static let padding: CGFloat = 12
    private static let lineSpacing: CGFloat = 6

    private let browser: BrowserState
    private let text = NSTextField(labelWithString: "")
    private let bar = NSProgressIndicator()
    private lazy var pause = NSButton(
        title: String(localized: "Pause"), target: self, action: #selector(pauseOrResume))
    private lazy var stop = NSButton(
        title: String(localized: "Stop"), target: self, action: #selector(stopOperation))
    /// Whether a transfer runs, as last seen.
    private var isRunning = false
    private var waiting: Task<Void, Never>?

    init(browser: BrowserState) {
        self.browser = browser
        super.init(frame: .zero)
        material = .popover
        blendingMode = .withinWindow
        state = .active
        wantsLayer = true
        layer?.cornerRadius = Self.padding
        isHidden = true
        text.font = .preferredFont(forTextStyle: .callout)
        text.lineBreakMode = .byTruncatingMiddle
        text.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        bar.isIndeterminate = false
        bar.style = .bar
        bar.minValue = 0
        bar.maxValue = 1
        layOut()
        Observing.follow(self) { $0.update() }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    private func layOut() {
        let lines = NSStackView(views: [text, bar])
        lines.orientation = .vertical
        lines.alignment = .leading
        lines.spacing = Self.lineSpacing
        for line in [text, bar] {
            line.widthAnchor.constraint(equalTo: lines.widthAnchor).isActive = true
        }
        let row = NSStackView(views: [lines, pause, stop])
        row.alignment = .bottom
        row.edgeInsets = NSEdgeInsets(
            top: Self.padding, left: Self.padding, bottom: Self.padding, right: Self.padding)
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: leadingAnchor),
            row.trailingAnchor.constraint(equalTo: trailingAnchor),
            row.topAnchor.constraint(equalTo: topAnchor),
            row.bottomAnchor.constraint(equalTo: bottomAnchor),
            widthAnchor.constraint(equalToConstant: Self.width + Self.padding * 2),
        ])
    }

    private func update() {
        guard let progress = browser.progress else {
            stopWaiting()
            return
        }
        text.stringValue = ProgressText.text(
            for: progress, isPaused: browser.isPaused, locale: .autoupdatingCurrent)
        bar.doubleValue = progress.fraction
        pause.title = browser.isPaused ? String(localized: "Resume") : String(localized: "Pause")
        if !isRunning { startWaiting() }
    }

    /// Shows the panel once the transfer has run for a second.
    private func startWaiting() {
        isRunning = true
        waiting = Task { [weak self] in
            try? await Task.sleep(for: Self.delay)
            guard !Task.isCancelled, let self else { return }
            isHidden = browser.progress == nil
        }
    }

    private func stopWaiting() {
        isRunning = false
        waiting?.cancel()
        waiting = nil
        isHidden = true
    }

    @objc private func pauseOrResume() {
        if browser.isPaused { browser.resumeOperation() } else { browser.pauseOperation() }
    }

    @objc private func stopOperation() {
        browser.cancelOperation()
    }
}
