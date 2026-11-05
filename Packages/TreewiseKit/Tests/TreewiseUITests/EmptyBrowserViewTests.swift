import SwiftUI
import Testing
import TreewiseUI

@Suite struct EmptyBrowserViewTests {
    @Test @MainActor func rendersWithoutContent() {
        let renderer = ImageRenderer(content: EmptyBrowserView())
        #expect(renderer.cgImage != nil)
    }
}
