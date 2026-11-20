import Foundation
import TreewiseCore

extension FolderTemplatesModel {
    /// The name Save Folder Structure as Template… proposes for `folder` (ADR 0091): for a
    /// year's folder the name of the folder above it with “Year”, else its own name.
    public static func proposedName(for folder: FileItem) -> String {
        guard let year = YearFolders.year(of: folder.id), String(year) == folder.name,
            let above = folder.parentID?.rawValue.split(separator: "/").last
        else { return folder.name }
        return String(localized: "\(String(above)) Year", bundle: .module)
    }
}
