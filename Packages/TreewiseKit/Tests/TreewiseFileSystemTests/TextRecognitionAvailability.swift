import Foundation
import Testing

/// Whether Vision's text recognition returns here. On a GitHub macOS runner it waits
/// forever inside Vision, and tests that call it hold every thread the test run has.
enum TextRecognitionAvailability {
    static let answers = ProcessInfo.processInfo.environment["GITHUB_ACTIONS"] == nil
    static let reason: Comment = "Vision's text recognition never returns on a GitHub runner"
}
