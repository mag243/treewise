import SwiftUI
import TreewiseCore

/// What a file's row shows of its place in the cloud, as on the Mac (ADR 0051, 0119): a
/// cloud with a download arrow for a file kept only online, nothing for one on the iPad.
struct OnlyOnlineMark: View {
    let item: FileItem

    var body: some View {
        if item.isOnlyOnline {
            Image(systemName: "icloud.and.arrow.down")
                .foregroundStyle(.secondary)
                .accessibilityLabel(Text("Only online", comment: "A file's cloud status"))
        }
    }
}
