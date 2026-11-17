import SwiftUI
import TreewiseCore
import TreewiseUI

/// Up to the enclosing folder where the width is compact, named after it as in Files; a
/// long press lists every enclosing folder (ADR 0132). At a location's top there is none,
/// and the system's back button returns to the locations.
struct EnclosingFolderButton: View {
    /// The room between the chevron and the name, as the system's back button has.
    private static let spacing: CGFloat = 4

    let browser: BrowserState

    var body: some View {
        let enclosing = Self.enclosing(in: browser)
        if let parent = enclosing.last {
            Menu {
                Items(browser: browser)
            } label: {
                // Its own row of symbol and name, as a toolbar would show a label's symbol only.
                HStack(spacing: Self.spacing) {
                    Image(systemName: "chevron.backward").fontWeight(.semibold)
                    Text(verbatim: parent.name)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(verbatim: parent.name))
            } primaryAction: {
                Task { await browser.navigate(pane: 0, to: FileItem.ID(parent.path)) }
            }
            // The UI tests find it by it.
            .accessibilityIdentifier("enclosingFolder")
        }
    }

    /// The folders that enclose the folder shown, from its location's top, as the path bar
    /// shows them.
    static func enclosing(in browser: BrowserState) -> [PathComponent] {
        let folder = browser.layout.focusedPane.activeTab.folder
        return Array(PathBar.crumbs(of: folder, in: browser).dropLast())
    }

    /// The enclosing folders to go to, nearest first: the long press's list, and the title's.
    struct Items: View {
        let browser: BrowserState

        var body: some View {
            let enclosing = EnclosingFolderButton.enclosing(in: browser)
            ForEach(Array(enclosing.reversed().enumerated()), id: \.offset) { _, folder in
                Button {
                    Task { await browser.navigate(pane: 0, to: FileItem.ID(folder.path)) }
                } label: {
                    Label {
                        Text(verbatim: folder.name)
                    } icon: {
                        Image(systemName: "folder")
                    }
                }
            }
        }
    }

    /// The title's menu of the enclosing folders, where there are any: at a location's top
    /// the title offers none.
    struct TitleMenu: ViewModifier {
        let browser: BrowserState
        let isShown: Bool

        func body(content: Content) -> some View {
            if isShown, !EnclosingFolderButton.enclosing(in: browser).isEmpty {
                content.toolbarTitleMenu { Items(browser: browser) }
            } else {
                content
            }
        }
    }
}
