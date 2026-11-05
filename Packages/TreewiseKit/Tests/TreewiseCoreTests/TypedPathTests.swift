import Testing
import TreewiseCore

/// What a path typed in the address bar points at, and how it completes (M5b).
@Suite struct TypedPathTests {
    private let home = "/Users/x"
    private let current = "/Users/x/Projects"

    private func resolve(_ text: String) -> String? {
        TypedPath.resolve(text, home: home, current: current)
    }

    @Test(arguments: [
        ("/Users/x/Documents", "/Users/x/Documents"),
        ("~", "/Users/x"),
        ("~/Documents", "/Users/x/Documents"),
        ("Treewise", "/Users/x/Projects/Treewise"),
        ("./Treewise/", "/Users/x/Projects/Treewise"),
        ("..", "/Users/x"),
        ("~/Documents/../Downloads", "/Users/x/Downloads"),
        ("/Users/x/Documents///", "/Users/x/Documents"),
        ("  /Volumes/T7  ", "/Volumes/T7"),
        ("/", "/"),
        ("/..", "/"),
    ])
    func resolvesATypedPath(text: String, path: String) {
        #expect(resolve(text) == path)
    }

    @Test(arguments: ["", "   ", "~someone/Documents"])
    func resolvesNothingForATextThatNamesNoPath(text: String) {
        #expect(resolve(text) == nil)
    }

    private let tree = [
        "/Users/x": ["Documents", "Downloads", "Desktop", "Music"],
        "/Users/x/Projects": ["Treewise", "treewise-releases"],
    ]

    private func complete(_ text: String) -> [String] {
        TypedPath.completions(for: text, home: home, current: current) { tree[$0] ?? [] }
    }

    @Test func completesTheLastFolderNameKeepingWhatWasTyped() {
        #expect(complete("~/Do") == ["~/Documents", "~/Downloads"])
        #expect(complete("/Users/x/de") == ["/Users/x/Desktop"], "case does not matter")
    }

    @Test func completesRelativeToTheCurrentFolder() {
        #expect(complete("tree") == ["Treewise", "treewise-releases"])
    }

    @Test func listsEveryFolderAfterASlash() {
        #expect(complete("~/") == ["~/Desktop", "~/Documents", "~/Downloads", "~/Music"])
    }

    @Test func looksForCompletionsInTheFolderOfTheLastSlash() {
        #expect(TypedPath.completionFolder(for: "~/Do", home: home, current: current) == home)
        #expect(TypedPath.completionFolder(for: "tree", home: home, current: current) == current)
        #expect(TypedPath.completionFolder(for: "", home: home, current: current) == nil)
    }

    @Test func completesNothingWithoutAFolderToLookIn() {
        #expect(complete("").isEmpty)
        #expect(complete("~/Nothing/Here").isEmpty)
    }
}
