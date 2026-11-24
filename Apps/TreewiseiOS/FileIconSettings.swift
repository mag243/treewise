import SwiftUI
import TreewiseCore
import TreewiseUI

/// The choice of how files' icons look (ADR 0151), each choice shown with a few files.
struct FileIconSettings: View {
    let settings: BrowserSettings

    /// The files each choice is shown with: a PDF, a spreadsheet and a document.
    private static let samples = ["Sample.pdf", "Sample.xlsx", "Sample.docx"]

    var body: some View {
        Section {
            Picker(
                selection: Binding(
                    get: { settings.fileIconLook }, set: { settings.fileIconLook = $0 })
            ) {
                ForEach(FileIconLook.allCases, id: \.self) { look in
                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            ForEach(Self.sampleItems, id: \.id) { FileIcon(item: $0) }
                        }
                        .environment(\.fileIconLook, look)
                        // The samples show the look; the choice's name says it.
                        .accessibilityHidden(true)
                        Text(Self.title(of: look))
                    }
                    .tag(look)
                }
            } label: {
                Text("File Icons")
            }
            .pickerStyle(.inline)
            // The section's header names it.
            .labelsHidden()
            // The UI tests find it by it.
            .accessibilityIdentifier("fileIconLook")
        } header: {
            Text("File Icons")
        }
    }

    private static func title(of look: FileIconLook) -> LocalizedStringKey {
        switch look {
        case .pageWithLabel: "Page with Label"
        case .pageWithBand: "Page with Band"
        case .filledPage: "Filled Page"
        case .system: "System Icons"
        }
    }

    /// Empty files of the samples' types, so Quick Look can give the system's icons.
    private static let sampleItems: [FileItem] = {
        let folder = FileManager.default.temporaryDirectory
            .appending(path: "FileIconSamples", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return samples.map { name in
            let url = folder.appending(path: name)
            if !FileManager.default.fileExists(atPath: url.path) {
                FileManager.default.createFile(atPath: url.path, contents: Data())
            }
            return FileItem(
                id: FileItem.ID(url.path), name: name, kind: .file, volume: VolumeID("samples"))
        }
    }()
}
