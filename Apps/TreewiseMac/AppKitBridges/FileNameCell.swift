import AppKit

/// The list's name cell: the name runs up to the cloud status of a file in
/// the cloud, and up to the cell's end for any other (ADR 0051).
final class FileNameCell: NSTableCellView {
    private static let spacing: CGFloat = 4

    private let cloudStatus = CloudStatusView()
    private var nameToEnd: NSLayoutConstraint?
    private var nameToStatus: NSLayoutConstraint?

    /// Shows the file's cloud status; see `CloudStatusView`.
    func showCloudStatus(isOnlyOnline: Bool, download: Double?) {
        cloudStatus.show(isOnlyOnline: isOnlyOnline, download: download)
        // Deactivated first, so the two never hold at once.
        nameToEnd?.isActive = false
        nameToStatus?.isActive = false
        let shows = isOnlyOnline || download != nil
        (shows ? nameToStatus : nameToEnd)?.isActive = true
    }

    /// Lays out the status at the cell's end, `padding` from it, and `name` before it.
    func placeCloudStatus(after name: NSTextField, padding: CGFloat) {
        addSubview(cloudStatus)
        nameToEnd = name.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -padding)
        nameToStatus = name.trailingAnchor.constraint(
            equalTo: cloudStatus.leadingAnchor, constant: -Self.spacing)
        nameToEnd?.isActive = true
        NSLayoutConstraint.activate([
            cloudStatus.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -padding),
            cloudStatus.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }
}
