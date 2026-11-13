import Testing
import TreewiseCore

/// The same folder a year before, found by the year in a folder's path (ADR 0090).
@Suite struct YearFoldersTests {
    @Test(arguments: [
        ("/Users/ada/Administration/2026/Tax", "/Users/ada/Administration/2025/Tax", 2026),
        ("/Users/ada/Administration/2026/Tax/VAT", "/Users/ada/Administration/2025/Tax/VAT", 2026),
        ("/Users/ada/Invoices/2026", "/Users/ada/Invoices/2025", 2026),
        ("/Volumes/T7/1999/2026/Salary", "/Volumes/T7/1999/2025/Salary", 2026),
        ("/Users/ada/Admin/2000", "/Users/ada/Admin/1999", 2000),
    ])
    func findsTheSameFolderAYearBefore(_ path: String, _ before: String, _ year: Int) {
        #expect(YearFolders.year(of: FileItem.ID(path)) == year)
        #expect(YearFolders.folderBefore(FileItem.ID(path)) == FileItem.ID(before))
    }

    @Test(arguments: [
        "/Users/ada/Administration/Tax", "/Users/ada/Tax 2026", "/Users/ada/2026x/Tax",
        "/Users/ada/3026/Tax", "/Users/ada/1899/Tax", "/Users/ada/Photos.zip//2026/Summer",
    ])
    func findsNoneWithoutAYearOfItsOwnInThePath(_ path: String) {
        #expect(YearFolders.folderBefore(FileItem.ID(path)) == nil)
    }
}
