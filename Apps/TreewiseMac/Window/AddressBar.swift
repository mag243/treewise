import AppKit
import TreewiseCore
import TreewiseUI

/// The address bar at the top of the window, as in Explorer (M5b), a row of
/// the window under the tab bar and over the command bar (ADR 0037): it takes
/// the window's whole width and is never hidden, however narrow the window.
/// It shows the path of the folder (`AddressPath`); a click on its empty
/// part, or ⌘L, turns it into a field to type a path in (`AddressField`).
@MainActor
final class AddressBar: NSView {
    private static let height: CGFloat = 26
    private static let cornerRadius: CGFloat = 6
    private static let margin: CGFloat = 6

    private let browser: BrowserState
    private let model: WindowModel
    private let background = RoundedFill(cornerRadius: cornerRadius)
    private var path: AddressPath?
    private var field: (view: NSTextField, coordinator: AddressFieldCoordinator)?
    /// The folder whose path's subfolders were read.
    private var readFolder: FileItem.ID?
    private var reading: Task<Void, Never>?

    init(browser: BrowserState, model: WindowModel) {
        self.browser = browser
        self.model = model
        super.init(frame: .zero)
        background.translatesAutoresizingMaskIntoConstraints = false
        addSubview(background)
        let margin = Self.margin
        NSLayoutConstraint.activate([
            background.leadingAnchor.constraint(equalTo: leadingAnchor, constant: margin),
            background.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -margin),
            background.topAnchor.constraint(equalTo: topAnchor, constant: margin),
            background.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -margin),
            background.heightAnchor.constraint(equalToConstant: Self.height),
        ])
        Observing.follow(self) { $0.update() }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    private var paneIndex: Int { browser.layout.focusedPaneIndex }

    private func update() {
        let folder = browser.layout.focusedPane.activeTab.folder
        if model.isEditingAddress {
            showField(for: folder)
        } else {
            showPath(for: folder)
        }
    }

    private func showField(for folder: FileItem.ID) {
        guard field == nil else { return }
        let model = model
        let coordinator = AddressFieldCoordinator(
            browser: browser, paneIndex: paneIndex, folder: folder
        ) { model.isEditingAddress = false }
        let view = AddressField.make(coordinator: coordinator, folder: folder)
        field = (view, coordinator)
        path?.removeFromSuperview()
        fill(with: view, centered: true)
    }

    private func showPath(for folder: FileItem.ID) {
        field?.view.removeFromSuperview()
        field = nil
        let path = path ?? makePath()
        if path.superview == nil { fill(with: path, centered: false) }
        let boundary = (LaunchOptions.boundary ?? []).map {
            MountPoint(path: $0.path, name: $0.lastPathComponent)
        }
        let crumbs = browser.addressPath(of: folder, boundary: boundary)
        path.show(crumbs, drop: DropRouting.action(for: browser, undoManager: SharedUndo.manager))
        if readFolder != folder {
            readFolder = folder
            readSubfolders(of: crumbs.dropLast(), into: path)
        }
    }

    private func makePath() -> AddressPath {
        let browser = browser
        let model = model
        let path = AddressPath(
            go: { [weak self] folder in
                guard let pane = self?.paneIndex else { return }
                Task { await browser.navigate(pane: pane, to: folder) }
            },
            edit: { model.isEditingAddress = true })
        self.path = path
        return path
    }

    /// Reads the subfolders behind each separator of the path.
    private func readSubfolders(of crumbs: ArraySlice<PathComponent>, into path: AddressPath) {
        reading?.cancel()
        let browser = browser
        reading = Task { [weak path] in
            var read: [String: [FileItem]] = [:]
            for crumb in crumbs {
                read[crumb.path] = await browser.subfolders(of: FileItem.ID(crumb.path))
            }
            guard !Task.isCancelled else { return }
            path?.show(subfolders: read)
        }
    }

    /// Puts `view` across the bar: at its own height in the middle when
    /// `centered`, else from top to bottom.
    private func fill(with view: NSView, centered: Bool) {
        view.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(view)
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: background.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: background.trailingAnchor),
            view.centerYAnchor.constraint(equalTo: background.centerYAnchor),
            centered
                ? view.heightAnchor.constraint(lessThanOrEqualTo: background.heightAnchor)
                : view.heightAnchor.constraint(equalTo: background.heightAnchor),
        ])
    }
}

/// A rounded rectangle in the fill of a quiet control, as behind the address bar.
@MainActor
final class RoundedFill: NSView {
    private let cornerRadius: CGFloat

    init(cornerRadius: CGFloat) {
        self.cornerRadius = cornerRadius
        super.init(frame: .zero)
        wantsLayer = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override var wantsUpdateLayer: Bool { true }

    override func updateLayer() {
        layer?.cornerRadius = cornerRadius
        layer?.backgroundColor = NSColor.quaternaryLabelColor.cgColor
    }
}
