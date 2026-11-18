import SwiftUI
import TreewiseCore
import UIKit

/// The items Share… offers to the system's share sheet.
struct ShareRequest: Identifiable {
    let id = UUID()
    let items: [FileItem]
}

/// The system's share sheet with the files of a `ShareRequest` (ADR 0132).
struct ShareSheet: UIViewControllerRepresentable {
    let request: ShareRequest

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let urls = request.items.map { URL(fileURLWithPath: $0.id.rawValue) }
        return UIActivityViewController(activityItems: urls, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
