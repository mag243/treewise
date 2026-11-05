import TreewiseCore

/// A row of the sidebar tree: a section heading, or a folder or location.
/// A node is a class because `NSOutlineView` identifies rows by object.
@MainActor
final class SidebarNode {
    enum Content {
        case section(String)
        /// "This Mac": the row that holds the volumes, as in the prototype.
        case computer(String)
        case item(FileItem)
    }

    let content: Content
    /// The rows below this one; `nil` until a folder is expanded for the first time.
    var children: [SidebarNode]?

    /// A section heading with its rows.
    init(section title: String, children: [SidebarNode]) {
        content = .section(title)
        self.children = children
    }

    /// The computer row, holding the locations.
    init(computer title: String, children: [SidebarNode]) {
        content = .computer(title)
        self.children = children
    }

    /// A folder or location. `expandable` ones load their subfolders on demand.
    init(item: FileItem, expandable: Bool) {
        content = .item(item)
        children = expandable ? nil : []
    }

    /// The folder or location the row stands for, if it is not a heading;
    /// the computer row stands for This Mac (ADR 0044).
    var item: FileItem? {
        switch content {
        case .item(let item): item
        case .computer: .computer()
        case .section: nil
        }
    }

    /// Whether the row has, or may have, rows below it.
    var isExpandable: Bool {
        switch content {
        case .section: true
        case .computer: children?.isEmpty == false
        case .item(let item): children.map { !$0.isEmpty } ?? item.isContainer
        }
    }
}
