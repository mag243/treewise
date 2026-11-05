import SwiftUI

/// The browser's content while it has nothing to show: an empty area at the
/// minimum window size.
public struct EmptyBrowserView: View {
    private static let minimumWidth: CGFloat = 640
    private static let minimumHeight: CGFloat = 400

    public init() {}

    public var body: some View {
        Color.clear
            .frame(minWidth: Self.minimumWidth, minHeight: Self.minimumHeight)
    }
}
