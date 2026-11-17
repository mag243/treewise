import SwiftUI
import TreewiseCore
import TreewiseUI
import UIKit

/// The chevron after a folder in the path bar: a tap opens a menu of the folders inside
/// it, as the Mac's address bar does. The folders are read when the menu opens, not with
/// the path, as a large cloud folder can take long to read (ADR 0121); the folder the path
/// goes on to is checked.
struct SubfolderMenu: UIViewRepresentable {
    /// The room a finger needs around the chevron.
    private static let tapSize: CGFloat = 28

    let browser: BrowserState
    /// The folder whose subfolders the menu lists.
    let folder: FileItem.ID
    /// The folder the path goes on to, if any.
    let next: FileItem.ID?
    /// The folder's name, for VoiceOver.
    let name: String

    func makeUIView(context: Context) -> UIButton {
        var configuration = UIButton.Configuration.plain()
        configuration.image = UIImage(
            systemName: "chevron.forward",
            withConfiguration: UIImage.SymbolConfiguration(textStyle: .caption2))
        configuration.baseForegroundColor = .tertiaryLabel
        configuration.contentInsets = .zero
        let button = UIButton(configuration: configuration)
        button.showsMenuAsPrimaryAction = true
        button.setContentHuggingPriority(.required, for: .horizontal)
        // The UI tests find it by it.
        button.accessibilityIdentifier = "subfolders"
        return button
    }

    func updateUIView(_ button: UIButton, context: Context) {
        button.accessibilityLabel = String(localized: "Folders in \(name)")
        button.menu = UIMenu(children: [menuElement])
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UIButton, context: Context) -> CGSize? {
        CGSize(width: Self.tapSize, height: Self.tapSize)
    }

    /// The folders, read each time the menu opens.
    private var menuElement: UIMenuElement {
        let (browser, folder, next) = (browser, folder, next)
        return UIDeferredMenuElement.uncached { completion in
            Task { @MainActor in
                let folders = await browser.subfolders(of: folder)
                completion(Self.actions(for: folders, next: next, browser: browser))
            }
        }
    }

    @MainActor
    private static func actions(
        for folders: [FileItem], next: FileItem.ID?, browser: BrowserState
    ) -> [UIMenuElement] {
        guard !folders.isEmpty else {
            return [
                UIAction(title: String(localized: "No Folders"), attributes: .disabled) { _ in }
            ]
        }
        return folders.map { folder in
            UIAction(
                title: folder.name, image: UIImage(systemName: ItemSymbol.name(for: folder)),
                state: folder.id == next ? .on : .off
            ) { _ in
                Task { await browser.navigate(pane: 0, to: folder.id) }
            }
        }
    }
}
